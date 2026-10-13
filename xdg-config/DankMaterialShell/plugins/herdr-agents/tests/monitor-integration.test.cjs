const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { spawn, fork } = require("node:child_process");
const { once } = require("node:events");
const { test } = require("node:test");

const cliFixture = `#!/usr/bin/node
const fs = require("node:fs");
const directory = process.env.HERDR_TEST_DIRECTORY;
fs.appendFileSync(directory + "/cli-calls", JSON.stringify({args: process.argv.slice(2), pid: process.pid}) + "\\n");
if (process.env.HERDR_TEST_MODE === "cleanup-cli") setTimeout(() => {}, 20000);
else if (process.argv[2] === "status") {
    const socket = process.env.HERDR_TEST_MODE === "cli-fallback" ? "" : fs.readFileSync(directory + "/endpoint", "utf8");
    console.log(JSON.stringify({server: {socket}}));
} else console.log(JSON.stringify({result: {type: "agent_list", agents: [{pane_id: "p1", agent: "opencode", agent_status: "blocked"}]}}));
`;

async function runMonitor(mode, expected, options = {}) {
    const directory = fs.mkdtempSync("/tmp/opencode/herdr-monitor-test-");
    let server;
    let monitor;
    try {
        for (const file of ["HerdrMonitor.qml", "AgentState.js", "HerdrProtocol.js"])
            fs.copyFileSync(path.join(__dirname, "..", file), path.join(directory, file));
        fs.copyFileSync(path.join(__dirname, "monitor-harness.qml"), path.join(directory, "shell.qml"));
        if (mode !== "missing") fs.writeFileSync(path.join(directory, "herdr"), cliFixture, { mode: 0o755 });
        const env = { ...process.env, QT_QPA_PLATFORM: "offscreen", PATH: directory,
            HERDR_SOCKET_PATH: "", HERDR_TEST_DIRECTORY: directory, HERDR_TEST_MODE: mode,
            HERDR_TEST_EXPECTED: JSON.stringify(expected), HERDR_TEST_SAFETY_MS: mode === "safety" ? "150" : "10000" };
        // Tests must never fall through to the person's real CLI or socket.
        if (!["missing", "cli-fallback", "cleanup-cli"].includes(mode)) {
            server = fork(path.join(__dirname, "socket-server.fixture.cjs"), [], { env, silent: true });
            await Promise.race([once(server, "message"), once(server, "exit").then(() => { throw new Error("Fixture server exited before readiness"); })]);
        } else fs.writeFileSync(path.join(directory, "endpoint"), "");
        if (options.override)
            env.HERDR_SOCKET_PATH = fs.readFileSync(path.join(directory, "endpoint"), "utf8");
        monitor = spawn("/usr/bin/qs", ["--no-color", "-p", directory], { env });
        let output = "";
        monitor.stdout.on("data", chunk => { output += chunk; });
        monitor.stderr.on("data", chunk => { output += chunk; });
        const deadline = setTimeout(() => monitor.kill("SIGKILL"), 15000);
        const [code, signal] = await once(monitor, "exit");
        clearTimeout(deadline);
        assert.equal(signal, null, output);
        assert.equal(code, 0, output);
        assert.doesNotMatch(output, /Unexpected state|harness timed out|failed to load configuration|TypeError|ReferenceError/i);
        const records = prefix => output.split("\n").filter(line => line.includes(prefix))
            .map(line => JSON.parse(line.slice(line.indexOf(prefix) + prefix.length)));
        const snapshots = records("HERDR_SNAPSHOT:");
        assert.deepEqual(snapshots.map(entry => entry.snapshot.available ? entry.snapshot.state : "unavailable"), expected, output);
        const diagnostics = records("HERDR_DIAGNOSTICS:")[0];
        assert.ok(diagnostics, output);
        // Allow the fixture to observe the native sockets closing on shell exit.
        await new Promise(resolve => setTimeout(resolve, 30));
        const statsFile = path.join(directory, "server-stats.json");
        const stats = fs.existsSync(statsFile) ? JSON.parse(fs.readFileSync(statsFile)) : null;
        const callsFile = path.join(directory, "cli-calls");
        const cliCalls = fs.existsSync(callsFile) ? fs.readFileSync(callsFile, "utf8").trim().split("\n").map(JSON.parse) : [];
        return { snapshots, diagnostics, stats, cliCalls };
    } finally {
        for (const child of [monitor, server]) {
            if (child && child.exitCode === null && child.signalCode === null) {
                const exited = once(child, "exit");
                child.kill("SIGKILL");
                await exited;
            }
        }
        fs.rmSync(directory, { recursive: true, force: true });
    }
}

test("native sockets synchronize with one discovery CLI and no list processes", async () => {
    const { diagnostics, stats, cliCalls } = await runMonitor("success", ["blocked"]);
    assert.equal(diagnostics.synchronized, true);
    assert.equal(diagnostics.initialCleared, true);
    assert.equal(diagnostics.mode, "events");
    assert.equal(stats.lists, 2);
    assert.deepEqual(cliCalls.map(call => call.args), [["status", "--json"]]);
});

test("explicit socket override avoids CLI discovery entirely", async () => {
    const { cliCalls } = await runMonitor("success", ["blocked"], { override: true });
    assert.equal(cliCalls.length, 0);
});

test("empty session stays subscribed to discover future agents", async () => {
    const { diagnostics, stats } = await runMonitor("new-agent", ["empty", "done"]);
    assert.equal(diagnostics.finalSnapshot.agents.length, 1);
    assert.equal(stats.subscriptions[0].filter(entry => entry.pane_id).length, 0);
    assert.ok(stats.subscriptions.at(-1).some(entry => entry.pane_id === "p1"));
});

test("state events update the snapshot in less than 250ms", async () => {
    const { snapshots, stats, cliCalls } = await runMonitor("event", ["idle", "done"]);
    assert.ok(snapshots.at(-1).time - stats.triggers[0].time < 250);
    assert.equal(cliCalls.length, 1);
});

test("a hundred-event burst is coalesced into one snapshot refresh", async () => {
    const { stats } = await runMonitor("burst", ["idle", "done"]);
    assert.equal(stats.lists, 3);
    assert.equal(stats.maxConcurrentRequests, 1);
});

test("busy event streams rotate before their input buffer fills", async () => {
    const { diagnostics, stats } = await runMonitor("stream-rotation", ["idle", "done"]);
    assert.equal(diagnostics.synchronized, true);
    assert.equal(stats.subscriptions.length, 2);
});

test("oversized unfinished event frames disconnect and resynchronize", async () => {
    const { diagnostics } = await runMonitor("event-partial", ["idle", "unavailable", "done"]);
    assert.equal(diagnostics.synchronized, true);
});

test("events during a request discard stale replies and get a follow-up", async () => {
    const { stats } = await runMonitor("race", ["idle", "done"]);
    assert.equal(stats.lists, 4);
    assert.equal(stats.maxConcurrentRequests, 1);
});

test("roster changes rebuild per-pane subscriptions and resynchronize", async () => {
    const { stats, diagnostics } = await runMonitor("roster", ["idle", "done"]);
    assert.deepEqual(stats.subscriptions.at(-1).filter(entry => entry.pane_id).map(entry => entry.pane_id), ["p1", "p2"]);
    assert.equal(diagnostics.synchronized, true);
});

test("tab removal clears agents and removes retired pane subscriptions", async () => {
    const { stats, diagnostics } = await runMonitor("removal", ["blocked", "empty"]);
    assert.equal(diagnostics.finalSnapshot.visible, false);
    assert.equal(stats.subscriptions.at(-1).filter(entry => entry.pane_id).length, 0);
});

for (const mode of ["invalid", "oversized", "timeout", "partial"])
    test(`${mode} socket response invalidates data and recovers`, async () => {
        const { diagnostics } = await runMonitor(mode, ["unavailable", "blocked"]);
        assert.equal(diagnostics.synchronized, true);
    });

test("subscription handshake timeout invalidates stale data and recovers", async () => {
    const { diagnostics } = await runMonitor("handshake", ["blocked", "unavailable", "blocked"]);
    assert.equal(diagnostics.synchronized, true);
});

test("unrelated response IDs do not replace the requested agent list", async () => {
    const { diagnostics } = await runMonitor("wrong-id", ["blocked"]);
    assert.equal(diagnostics.finalSnapshot.agents.length, 1);
});

test("native framing preserves Unicode split inside a UTF-8 character", async () => {
    const { diagnostics } = await runMonitor("utf8", ["blocked"]);
    assert.equal(diagnostics.finalSnapshot.agents[0].title, "Traducción 🐑 — sesión");
});

for (const mode of ["reconnect", "relocate"])
    test(`${mode} clears stale data and discovers the new endpoint`, async () => {
        const { diagnostics, cliCalls } = await runMonitor(mode, ["idle", "unavailable", "done"]);
        assert.equal(diagnostics.synchronized, true);
        assert.ok(cliCalls.length > 1);
    });

test("unsupported subscriptions retain socket polling as a fallback", async () => {
    const { diagnostics, cliCalls } = await runMonitor("unsupported", ["blocked"]);
    assert.equal(diagnostics.mode, "fallback");
    assert.ok(cliCalls.every(call => call.args[0] === "status"));
});

test("occasional safety snapshots repair a missed event", async () => {
    const { cliCalls } = await runMonitor("safety", ["idle", "done"]);
    assert.equal(cliCalls.length, 1);
});

test("slow snapshot requests never overlap", async () => {
    const { stats } = await runMonitor("slow", ["idle", "done"]);
    assert.equal(stats.maxConcurrentRequests, 1);
    assert.equal(stats.lists, 4);
});

test("CLI polling remains a last resort when no socket can be discovered", async () => {
    const { diagnostics, cliCalls } = await runMonitor("cli-fallback", ["unavailable", "blocked"]);
    assert.equal(diagnostics.mode, "fallback");
    assert.ok(cliCalls.some(call => call.args[0] === "agent"));
});

test("missing CLI executable fails within the deadline", async () => {
    const { diagnostics } = await runMonitor("missing", ["unavailable"]);
    assert.equal(diagnostics.finalSnapshot.filled, false);
});

test("destroying the monitor closes its native sockets", async () => {
    const { diagnostics, stats } = await runMonitor("cleanup", ["blocked"]);
    assert.equal(diagnostics.cleanupComplete, true);
    assert.equal(stats.openConnections, 0);
});

test("destroying the monitor kills its in-flight discovery CLI", async () => {
    const { diagnostics, cliCalls } = await runMonitor("cleanup-cli", []);
    assert.equal(diagnostics.cleanupComplete, true);
    assert.equal(cliCalls.length, 1);
    assert.throws(() => process.kill(cliCalls[0].pid, 0), { code: "ESRCH" });
});
