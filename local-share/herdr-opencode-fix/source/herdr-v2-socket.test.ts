import { afterEach, expect, test } from "bun:test";
import { spawn } from "node:child_process";
import { createServer } from "node:net";
import { mkdtemp, rm } from "node:fs/promises";
import { createInterface } from "node:readline";
import { fileURLToPath } from "node:url";

type Report = { params: { pane_id: string; agent_session_id: string; state?: string } };
const cleanups: Array<() => Promise<void>> = [];
afterEach(async () => {
  for (const cleanup of cleanups.splice(0).reverse()) await cleanup();
});

async function waitUntil(predicate: () => boolean) {
  const deadline = Date.now() + 3000;
  while (!predicate()) {
    if (Date.now() >= deadline) throw new Error("Timed out waiting for a socket report");
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
}

async function socketHarness() {
  const directory = await mkdtemp("/tmp/opencode/herdr-v2-socket-");
  const socketPath = `${directory}/test.sock`;
  const reports: Report[] = [];
  let dropConnections = false;
  const server = createServer((socket) => {
    if (dropConnections) {
      socket.destroy();
      return;
    }
    let buffer = "";
    socket.on("error", () => {});
    socket.on("data", (chunk) => {
      buffer += chunk.toString();
      const boundary = buffer.indexOf("\n");
      if (boundary === -1) return;
      const request = JSON.parse(buffer.slice(0, boundary));
      buffer = buffer.slice(boundary + 1);
      reports.push(request);
      socket.end(`${JSON.stringify({ id: request.id, result: {} })}\n`);
    });
  });
  await new Promise<void>((resolve, reject) => {
    server.once("error", reject);
    server.listen(socketPath, resolve);
  });
  cleanups.push(async () => {
    await new Promise<void>((resolve) => server.close(() => resolve()));
    await rm(directory, { recursive: true });
  });
  return {
    socketPath, reports,
    drop(value: boolean) { dropConnections = value; },
    latest(pane: string) {
      return reports.findLast((report) => report.params.pane_id === pane && report.params.state !== undefined)?.params.state;
    },
  };
}

async function worker(socketPath: string, pane: string, sessionID: string) {
  const child = spawn("node", [fileURLToPath(new URL("./herdr-v2-socket-worker.mjs", import.meta.url)), sessionID], {
    env: { ...process.env, HERDR_ENV: "1", HERDR_SOCKET_PATH: socketPath, HERDR_PANE_ID: pane },
    stdio: ["pipe", "pipe", "pipe"],
  });
  const acknowledgements = new Map<number, () => void>();
  let ready = false;
  let nextID = 0;
  let errors = "";
  child.stderr.on("data", (chunk) => errors += chunk.toString());
  createInterface({ input: child.stdout }).on("line", (line) => {
    const response = JSON.parse(line);
    if (response.ready) ready = true;
    acknowledgements.get(response.acknowledged)?.();
    acknowledgements.delete(response.acknowledged);
  });
  child.on("error", (error) => errors += error.message);
  cleanups.push(async () => {
    if (child.exitCode !== null) return;
    const stopped = new Promise<void>((resolve) => child.once("exit", () => resolve()));
    child.stdin.end();
    const timer = setTimeout(() => child.kill("SIGTERM"), 1000);
    await stopped;
    clearTimeout(timer);
  });
  await waitUntil(() => {
    if (child.exitCode !== null) throw new Error(`Socket worker failed: ${errors}`);
    return ready;
  });
  return {
    async send(command: object) {
      const id = ++nextID;
      const acknowledged = new Promise<void>((resolve) => acknowledgements.set(id, resolve));
      child.stdin.write(`${JSON.stringify({ ...command, id })}\n`);
      await Promise.race([
        acknowledged,
        new Promise<never>((_, reject) => {
          const timer = setTimeout(() => reject(new Error(`Worker command timed out: ${errors}`)), 3000);
          timer.unref();
          acknowledged.finally(() => clearTimeout(timer));
        }),
      ]);
    },
  };
}

test("real sockets keep two pane processes isolated while reconciling activity and blockers", async () => {
  const harness = await socketHarness();
  const first = await worker(harness.socketPath, "test-pane-1", "a");
  const second = await worker(harness.socketPath, "test-pane-2", "b");
  await waitUntil(() => harness.latest("test-pane-1") === "idle" && harness.latest("test-pane-2") === "idle");
  await first.send({ type: "status", sessionID: "a", status: "running" });
  await waitUntil(() => harness.latest("test-pane-1") === "working");
  expect(harness.latest("test-pane-2")).toBe("idle");
  for (const client of [first, second]) {
    await client.send({ type: "event", name: "session.execution.started", data: { sessionID: "child-a" } });
  }
  await first.send({ type: "status", sessionID: "a", status: "idle" });
  await new Promise((resolve) => setTimeout(resolve, 150));
  expect(harness.latest("test-pane-1")).toBe("working");
  expect(harness.latest("test-pane-2")).toBe("idle");
  for (const client of [first, second]) {
    await client.send({ type: "event", name: "permission.asked", data: { sessionID: "child-a", id: "p" } });
  }
  await waitUntil(() => harness.latest("test-pane-1") === "blocked");
  expect(harness.latest("test-pane-2")).toBe("idle");
  await first.send({ type: "event", name: "permission.replied", data: { sessionID: "child-a", requestID: "p" } });
  await waitUntil(() => harness.latest("test-pane-1") === "working");
  await first.send({ type: "event", name: "session.execution.succeeded", data: { sessionID: "child-a" } });
  await waitUntil(() => harness.latest("test-pane-1") === "idle");
  expect(harness.reports.every((report) => report.params.agent_session_id ===
    (report.params.pane_id === "test-pane-1" ? "a" : "b"))).toBe(true);
});

test("real sockets retry home settlement and stop reporting after disposal", async () => {
  const harness = await socketHarness();
  const client = await worker(harness.socketPath, "test-pane", "a");
  await waitUntil(() => harness.latest("test-pane") === "idle");
  await client.send({ type: "event", name: "session.execution.started", data: { sessionID: "a" } });
  await waitUntil(() => harness.latest("test-pane") === "working");
  harness.drop(true);
  await client.send({ type: "home" });
  await new Promise((resolve) => setTimeout(resolve, 200));
  expect(harness.latest("test-pane")).toBe("working");
  harness.drop(false);
  await waitUntil(() => harness.latest("test-pane") === "idle");
  await client.send({ type: "dispose" });
  const count = harness.reports.length;
  await client.send({ type: "select", sessionID: "b" });
  await client.send({ type: "event", name: "session.execution.started", data: { sessionID: "b" } });
  await new Promise((resolve) => setTimeout(resolve, 200));
  expect(harness.reports).toHaveLength(count);
});
