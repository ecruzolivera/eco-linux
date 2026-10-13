const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { test } = require("node:test");

const protocol = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, "../HerdrProtocol.js"), "utf8"), protocol);
const plain = value => JSON.parse(JSON.stringify(value));

test("frames only read-only snapshot and subscription requests", () => {
    const frame = protocol.frameRequest("test:1", "agent.list", {});
    assert.ok(frame.endsWith("\n"));
    assert.deepEqual(JSON.parse(frame), { id: "test:1", method: "agent.list", params: {} });
    assert.throws(() => protocol.frameRequest("test:1", "pane.close", {}), /Unsupported/);
});

test("parses response, error and both event-envelope formats", () => {
    for (const message of [
        { id: "1", result: { type: "agent_list", agents: [] } },
        { id: "2", error: { code: "unsupported", message: "Unsupported" } },
        { event: "pane_agent_status_changed", data: { pane_id: "p1", agent_status: "done" } },
        { event: "pane.agent_status_changed", data: { pane_id: "p1", agent_status: "done" } }
    ]) assert.deepEqual(plain(protocol.parseLine(JSON.stringify(message))), message);
    assert.equal(protocol.parseLine("  \r"), null);
});

test("cumulative framing retains partial lines and consumes each complete line once", () => {
    const first = protocol.takeLines('{"id":"1"}\n{"id":', 0);
    assert.deepEqual(plain(first), { lines: ['{"id":"1"}'], offset: 11 });
    const second = protocol.takeLines('{"id":"1"}\n{"id":"2"}\n', first.offset);
    assert.deepEqual(plain(second), { lines: ['{"id":"2"}'], offset: 22 });
    assert.deepEqual(plain(protocol.takeLines('{"id":"1"}\n{"id":"2"}\n', second.offset)), { lines: [], offset: 22 });
});

test("unfinished input is bounded as well as complete JSON frames", () => {
    assert.throws(() => protocol.takeLines("x".repeat(1024 * 1024 + 1), 0), /buffer exceeded/);
});

test("rejects malformed and oversized envelopes", () => {
    for (const line of ["not json", "null", "[]", "{}", '{"event":"pane.closed"}'])
        assert.throws(() => protocol.parseLine(line), /Herdr returned/);
    assert.throws(() => protocol.parseLine("x".repeat(1024 * 1024 + 1)), /larger than one MiB/);
    assert.throws(() => protocol.frameRequest("x".repeat(1024 * 1024), "agent.list", {}), /too large/);
});

test("builds unique per-pane subscriptions and global lifecycle subscriptions", () => {
    const agents = [{ paneId: "p2" }, { paneId: "p1" }, { paneId: "p2" }];
    const subscriptions = plain(protocol.subscriptions(agents));
    assert.deepEqual(subscriptions.filter(entry => entry.pane_id), [
        { type: "pane.agent_status_changed", pane_id: "p1" },
        { type: "pane.agent_status_changed", pane_id: "p2" }
    ]);
    for (const type of ["pane.created", "pane.closed", "pane.updated", "pane.agent_detected",
        "pane.exited", "pane.moved", "tab.closed", "workspace.closed"])
        assert.ok(subscriptions.some(entry => entry.type === type), type);
    assert.equal(protocol.subscriptions([]).length, 8);
});

test("roster comparison ignores status, order and duplicate IDs", () => {
    assert.equal(protocol.rosterKey([{ paneId: "p2" }, { paneId: "p1" }]),
        protocol.rosterKey([{ paneId: "p1", state: "done" }, { paneId: "p2" }, { paneId: "p2" }]));
    assert.notEqual(protocol.rosterKey([{ paneId: "p1" }]), protocol.rosterKey([]));
});

test("recognizes relevant events without subscribing to terminal output", () => {
    for (const event of ["pane.agent_status_changed", "pane_agent_status_changed", "pane.agent_detected",
        "pane_agent_detected", "pane.updated", "pane_updated", "pane_created", "workspace_closed"])
        assert.equal(protocol.isRelevantEvent({ event }), true, event);
    for (const event of ["pane_output_changed", "pane.output_matched", "workspace_focused", "future.event"])
        assert.equal(protocol.isRelevantEvent({ event }), false, event);
});

test("resolves status paths without hardcoding a user's home", () => {
    const socket = "/tmp/a home with spaces & symbols|/herdr.sock";
    assert.equal(protocol.socketPathFromStatus(JSON.stringify({ server: { socket } })), socket);
    for (const text of ["not json", "null", "{}", '{"server":{"socket":""}}'])
        assert.throws(() => protocol.socketPathFromStatus(text), /Herdr/);
});

test("reconnect backoff starts at one second and is capped at thirty", () => {
    assert.deepEqual([0, 1, 2, 3, 4, 5, 10].map(protocol.reconnectDelay), [1000, 2000, 4000, 8000, 16000, 30000, 30000]);
});
