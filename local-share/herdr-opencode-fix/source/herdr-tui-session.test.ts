import { afterEach, beforeEach, expect, mock, test } from "bun:test";

const requests: unknown[] = [];
const activeDisposers: Array<() => void> = [];
const requestWaiters: Array<() => void> = [];
const stateWaiters: Array<() => void> = [];
let importCounter = 0;
let holdConnections = false;
let failConnections = false;
let connectionAttempts = 0;
const connections: Array<() => void> = [];

mock.module("node:net", () => ({
  default: {
    createConnection(_path: string, onConnect: () => void) {
      connectionAttempts += 1;
      const handlers = new Map<string, () => void>();
      const client = {
        destroyed: false,
        write(input: string) {
          if (client.destroyed) return;
          const request = JSON.parse(input.trim());
          requests.push(request);
          if (isRecord(request) && isRecord(request.params) && request.params.state !== undefined) {
            stateWaiters.shift()?.();
          }
          requestWaiters.shift()?.();
          queueMicrotask(() => client.emit("data"));
        },
        setTimeout() {},
        on(event: string, handler: () => void) {
          handlers.set(event, handler);
        },
        destroy() {
          client.destroyed = true;
        },
        emit(event: string) {
          handlers.get(event)?.();
        },
      };
      if (holdConnections) connections.push(onConnect);
      else if (failConnections) queueMicrotask(() => client.emit("error"));
      else queueMicrotask(onConnect);
      return client;
    },
  },
}));

beforeEach(() => {
  requests.length = 0;
  requestWaiters.length = 0;
  stateWaiters.length = 0;
  holdConnections = false;
  failConnections = false;
  connectionAttempts = 0;
  connections.length = 0;
  process.env.HERDR_ENV = "1";
  process.env.HERDR_SOCKET_PATH = "test.sock";
  process.env.HERDR_PANE_ID = "test:p1";
});

afterEach(() => {
  for (const dispose of activeDisposers.splice(0)) {
    dispose();
  }
});

async function loadPlugin() {
  importCounter += 1;
  const module = await import(`./herdr-tui-session.js?test=${importCounter}`);
  return module.default;
}

function fakeApi() {
  const sessions = new Map<string, { id: string; parentID?: string }>();
  const statuses: Record<string, { type: string }> = {};
  const permissions: Array<{ id: string; sessionID: string; tool?: { messageID: string; callID: string } }> = [];
  const questions: typeof permissions = [];
  const messages = new Map<string, { info?: { error?: { name: string } }; parts: Array<object> }>();
  const listeners = new Map<string, Set<(event: object) => void>>();
  const calls: string[] = [];
  let current: { name: string; params?: { sessionID: string } } = { name: "home" };
  let dispose: (() => void) | undefined;
  activeDisposers.push(() => dispose?.());

  return {
    statuses, permissions, questions, messages, listeners, calls,
    emit(type: string, properties: object) {
      for (const receive of listeners.get(type) ?? []) receive({ type, properties });
    },
    api: {
      client: {
        session: {
          async get({ sessionID }: { sessionID: string }) {
            calls.push(`get:${sessionID}`);
            const data = sessions.get(sessionID);
            if (!data) throw new Error("session not found");
            return { data };
          },
          async status() { calls.push("status"); return { data: { ...statuses } }; },
          async message({ messageID }: { sessionID: string; messageID: string }) {
            calls.push(`message:${messageID}`);
            const data = messages.get(messageID);
            if (!data) throw new Error("message unavailable");
            return { data };
          },
        },
        permission: { async list() { return { data: [...permissions] }; } },
        question: { async list() { return { data: [...questions] }; } },
      },
      event: {
        on(type: string, receive: (event: object) => void) {
          if (!listeners.has(type)) listeners.set(type, new Set());
          listeners.get(type)!.add(receive);
          return () => listeners.get(type)!.delete(receive);
        },
      },
      route: {
        get current() {
          return current;
        },
      },
      state: {
        session: {
          get(sessionID: string) {
            return sessions.get(sessionID);
          },
        },
      },
      lifecycle: {
        onDispose(handler: () => void) {
          dispose = handler;
          return () => {};
        },
      },
    },
    addSession(session: { id: string; parentID?: string }) {
      sessions.set(session.id, session);
    },
    select(sessionID: string) {
      current = { name: "session", params: { sessionID } };
    },
    home() { current = { name: "home" }; },
    dispose() {
      dispose?.();
    },
  };
}

function waitForNextRequest(): Promise<void> {
  return new Promise((resolve) => requestWaiters.push(resolve));
}

function waitForStateReport(): Promise<void> {
  return new Promise((resolve) => stateWaiters.push(resolve));
}

test("reports a root session when only the local route changes", async () => {
  const plugin = await loadPlugin();
  const tui = fakeApi();
  tui.addSession({ id: "session-a" });
  await plugin.tui(tui.api);

  const dispatched = waitForNextRequest();
  tui.select("session-a");
  await dispatched;

  expect(requests).toHaveLength(1);
  expect(requestParam(requests[0], "agent_session_id")).toBe("session-a");
  expect(requestParam(requests[0], "session_start_source")).toBe("select");
  expect(requestParam(requests[0], "seq")).toBeUndefined();
});

test("retries an initial selection while Herdr detects the process", async () => {
  const plugin = await loadPlugin();
  const tui = fakeApi();
  tui.addSession({ id: "session-a" });
  tui.select("session-a");

  await plugin.tui(tui.api);
  await new Promise((resolve) => setTimeout(resolve, 125));

  const selections = requests.filter((request) => requestParam(request, "state") === undefined);
  expect(selections.length).toBeGreaterThanOrEqual(2);
  expect(selections.every((request) => requestParam(request, "agent_session_id") === "session-a")).toBe(true);
});

test("does not report root sessions not selected by this TUI", async () => {
  const plugin = await loadPlugin();
  const tui = fakeApi();
  tui.addSession({ id: "session-a" });
  tui.addSession({ id: "session-b" });
  tui.select("session-a");
  await plugin.tui(tui.api);

  await new Promise((resolve) => setTimeout(resolve, 125));

  expect(requests.length).toBeGreaterThan(0);
  expect(requests.every((request) => requestParam(request, "agent_session_id") === "session-a")).toBe(
    true,
  );
});

test("does not replace the root session with a selected child session", async () => {
  const plugin = await loadPlugin();
  const tui = fakeApi();
  tui.addSession({ id: "root-session" });
  tui.addSession({ id: "child-session", parentID: "root-session" });
  tui.select("root-session");
  await plugin.tui(tui.api);
  await flushReports();

  tui.select("child-session");
  await new Promise((resolve) => setTimeout(resolve, 125));

  expect(requests.length).toBeGreaterThan(0);
  expect(requests.every((r) => requestParam(r, "agent_session_id") === "root-session")).toBe(true);
});

test("stops route polling when the TUI plugin is disposed", async () => {
  const plugin = await loadPlugin();
  const tui = fakeApi();
  tui.addSession({ id: "session-a" });
  await plugin.tui(tui.api);
  tui.dispose();
  tui.select("session-a");

  await new Promise((resolve) => setTimeout(resolve, 125));

  expect(requests).toHaveLength(0);
});

function requestParam(request: unknown, name: string): unknown {
  if (!isRecord(request) || !isRecord(request.params)) {
    return undefined;
  }
  return request.params[name];
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function v2Api() {
  const sessions = new Map<string, { id: string; parentID?: string; outcome?: string }>([
    ["a", { id: "a" }],
    ["b", { id: "b" }],
    ["child", { id: "child", parentID: "a" }],
  ]);
  let route = { type: "session", sessionID: "a" };
  const listeners = new Set<(event: unknown) => void>();
  const permissions = new Map<string, Array<{ id: string }> | undefined>();
  const forms = new Map<string, Array<{ id: string }> | undefined>();
  const statuses = new Map<string, string>();
  return {
    api: {
      ui: { router: { current: () => route } },
      data: {
        session: {
          get: (id: string) => sessions.get(id),
          family: () => [...sessions.keys()],
          status: (id: string) => statuses.get(id) ?? "idle",
          permission: { list: (id: string) => permissions.get(id) },
          form: { list: (id: string) => forms.get(id) },
        },
        listen: (handler: (event: unknown) => void) => {
          listeners.add(handler);
          return () => listeners.delete(handler);
        },
      },
    },
    select(sessionID: string) { route = { type: "session", sessionID }; },
    home() { route = { type: "home", sessionID: "" }; },
    emit(type: string, data?: object) {
      for (const listener of listeners) listener({ details: { type, data } });
    },
    listeners,
    sessions,
    permissions,
    forms,
    statuses,
  };
}

const flushReports = () => new Promise((resolve) => setTimeout(resolve, 10));
const states = () => requests.filter((r) => requestParam(r, "state") !== undefined)
  .map((r) => requestParam(r, "state"));

function familyApi() {
  const tui = fakeApi();
  tui.addSession({ id: "root" });
  tui.addSession({ id: "child", parentID: "root" });
  tui.addSession({ id: "sibling", parentID: "root" });
  tui.addSession({ id: "grandchild", parentID: "child" });
  tui.addSession({ id: "other" });
  tui.select("root");
  return tui;
}

test("V1 hydrates active descendants and keeps working until the whole family settles", async () => {
  const tui = familyApi();
  tui.statuses.child = { type: "busy" };
  tui.statuses.grandchild = { type: "retry" };
  tui.statuses.other = { type: "busy" };
  await (await loadPlugin()).tui(tui.api);
  await flushReports();
  expect(states().at(-1)).toBe("working");
  tui.emit("session.status", { sessionID: "child", status: { type: "idle" } });
  await flushReports();
  expect(states().at(-1)).toBe("working");
  tui.emit("session.status", { sessionID: "grandchild", status: { type: "idle" } });
  await flushReports();
  expect(states().at(-1)).toBe("idle");
  expect(requests.every((r) => requestParam(r, "agent_session_id") === "root")).toBe(true);
});

test("V1 retains sibling blockers and cancellation does not finish an active parent", async () => {
  const tui = familyApi();
  tui.statuses.root = { type: "busy" };
  await (await loadPlugin()).tui(tui.api);
  await flushReports();
  tui.emit("permission.asked", { id: "p", sessionID: "child" });
  tui.emit("question.asked", { id: "q", sessionID: "sibling", tool: { messageID: "m", callID: "call" } });
  await flushReports();
  expect(states().at(-1)).toBe("blocked");
  tui.emit("permission.replied", { requestID: "p", sessionID: "child" });
  await flushReports();
  expect(states().at(-1)).toBe("blocked");
  tui.emit("session.idle", { sessionID: "sibling" });
  await flushReports();
  expect(states().at(-1)).toBe("blocked");
  tui.emit("message.part.updated", { part: {
    type: "tool", sessionID: "sibling", messageID: "m", callID: "call", state: { status: "error" },
  } });
  await flushReports();
  expect(states().at(-1)).toBe("working");
  tui.emit("session.idle", { sessionID: "root" });
  await flushReports();
  expect(states().at(-1)).toBe("idle");
});

test("V1 hydration rejects aborted tool requests even if their session is busy again", async () => {
  for (const kind of ["permissions", "questions"] as const) {
    const tui = familyApi();
    tui.statuses.child = { type: "busy" };
    tui[kind].push({ id: "stale", sessionID: "child", tool: { messageID: "m", callID: "call" } });
    tui.messages.set("m", { info: { error: { name: "MessageAbortedError" } }, parts: [
      { type: "tool", callID: "call", state: { status: "error" } },
    ] });
    await (await loadPlugin()).tui(tui.api);
    await flushReports();
    expect(states().at(-1)).toBe("working");
    tui.dispose();
  }
});

test("V1 validates pending tools instead of assuming an idle owner has no requests", async () => {
  const tui = familyApi();
  tui.permissions.push({ id: "pending", sessionID: "child", tool: { messageID: "m", callID: "call" } });
  tui.messages.set("m", { parts: [{ type: "tool", callID: "call", state: { status: "running" } }] });
  await (await loadPlugin()).tui(tui.api);
  await flushReports();
  expect(states().at(-1)).toBe("blocked");
  tui.emit("message.part.updated", { part: {
    type: "tool", sessionID: "child", messageID: "m", callID: "call", state: { status: "error" },
  } });
  await flushReports();
  expect(states().at(-1)).toBe("idle");
});

test("V1 replays completion and replies over a late initial snapshot", async () => {
  const tui = familyApi();
  let resolveStatus!: (result: { data: Record<string, { type: string }> }) => void;
  tui.api.client.session.status = () => new Promise((resolve) => { resolveStatus = resolve; });
  tui.permissions.push({ id: "p", sessionID: "child" });
  await (await loadPlugin()).tui(tui.api);
  await flushReports();
  expect(states()).not.toContain("idle");
  tui.emit("session.idle", { sessionID: "child" });
  tui.emit("permission.replied", { sessionID: "child", requestID: "p" });
  resolveStatus({ data: { child: { type: "busy" } } });
  await flushReports();
  expect(states().at(-1)).toBe("idle");
});

test("V1 retains replies received between failed hydration and its retry", async () => {
  const tui = familyApi();
  tui.permissions.push({ id: "p", sessionID: "child" });
  const status = tui.api.client.session.status;
  tui.api.client.session.status = async () => {
    tui.api.client.session.status = status;
    throw new Error("temporarily unavailable");
  };
  await (await loadPlugin()).tui(tui.api);
  await flushReports();
  tui.emit("permission.replied", { sessionID: "child", requestID: "p" });
  await new Promise((resolve) => setTimeout(resolve, 650));
  expect(states().at(-1)).toBe("idle");
  expect(states()).not.toContain("blocked");
});

test("V1 deleted sessions cannot return through a late hydration snapshot", async () => {
  const tui = familyApi();
  let resolveStatus!: (result: { data: Record<string, { type: string }> }) => void;
  tui.api.client.session.status = () => new Promise((resolve) => { resolveStatus = resolve; });
  tui.permissions.push({ id: "p", sessionID: "child" });
  await (await loadPlugin()).tui(tui.api);
  await flushReports();
  tui.emit("session.deleted", { info: { id: "child", parentID: "root" } });
  resolveStatus({ data: { child: { type: "busy" } } });
  await flushReports();
  expect(states().at(-1)).toBe("idle");
});

test("V1 ignores stale hydration across A/B/A route changes and disposal", async () => {
  const tui = familyApi();
  let resolveOld!: (result: { data: Record<string, { type: string }> }) => void;
  const status = tui.api.client.session.status;
  tui.api.client.session.status = () => {
    tui.api.client.session.status = status;
    return new Promise((resolve) => { resolveOld = resolve; });
  };
  await (await loadPlugin()).tui(tui.api);
  tui.select("other");
  tui.emit("session.updated", { info: { id: "other" } });
  await flushReports();
  tui.select("root");
  tui.emit("session.updated", { info: { id: "root" } });
  await flushReports();
  requests.length = 0;
  resolveOld({ data: { root: { type: "busy" } } });
  await flushReports();
  expect(states()).not.toContain("working");
  tui.dispose();
  expect([...tui.listeners.values()].every((set) => set.size === 0)).toBe(true);
});

test("V1 a directly attached child owns its descendants, not its parent or siblings", async () => {
  const tui = familyApi();
  tui.select("child");
  tui.statuses.root = { type: "busy" };
  tui.statuses.sibling = { type: "busy" };
  await (await loadPlugin()).tui(tui.api);
  await flushReports();
  expect(states().at(-1)).toBe("idle");
  tui.emit("session.status", { sessionID: "grandchild", status: { type: "busy" } });
  await flushReports();
  expect(states().at(-1)).toBe("working");
  tui.select("grandchild");
  tui.emit("session.updated", { info: { id: "grandchild", parentID: "child" } });
  await flushReports();
  expect(requests.every((r) => requestParam(r, "agent_session_id") === "child")).toBe(true);
});

test("V1 a terminal tool event during hydration cannot revive a cancelled blocker", async () => {
  const tui = familyApi();
  tui.questions.push({ id: "q", sessionID: "child", tool: { messageID: "m", callID: "call" } });
  let resolveMessage!: (result: { data: { parts: Array<object> } }) => void;
  tui.api.client.session.message = () => new Promise((resolve) => { resolveMessage = resolve; });
  await (await loadPlugin()).tui(tui.api);
  await flushReports();
  tui.emit("message.part.updated", { part: {
    type: "tool", sessionID: "child", messageID: "m", callID: "call", state: { status: "error" },
  } });
  resolveMessage({ data: { parts: [{ type: "tool", callID: "call", state: { status: "running" } }] } });
  await flushReports();
  expect(states().at(-1)).toBe("idle");
});

test("V1 unknown tool evidence remains blocked and retries failed message reads", async () => {
  const tui = familyApi();
  tui.permissions.push({ id: "p", sessionID: "child", tool: { messageID: "m", callID: "call" } });
  await (await loadPlugin()).tui(tui.api);
  await flushReports();
  expect(states().at(-1)).toBe("blocked");
  tui.messages.set("m", { parts: [{ type: "tool", callID: "call", state: { status: "error" } }] });
  await new Promise((resolve) => setTimeout(resolve, 650));
  expect(states().at(-1)).toBe("idle");
});

test("V1 request validation matches the exact tool and deduplicates message reads", async () => {
  const tui = familyApi();
  tui.permissions.push({ id: "p", sessionID: "child", tool: { messageID: "m", callID: "running" } });
  tui.questions.push({ id: "q", sessionID: "child", tool: { messageID: "m", callID: "finished" } });
  tui.messages.set("m", { parts: [
    { type: "tool", callID: "running", state: { status: "running" } },
    { type: "tool", callID: "finished", state: { status: "completed" } },
  ] });
  await (await loadPlugin()).tui(tui.api);
  await flushReports();
  expect(states().at(-1)).toBe("blocked");
  expect(tui.calls.filter((call) => call === "message:m")).toHaveLength(1);
  tui.emit("permission.replied", { sessionID: "child", requestID: "p" });
  await flushReports();
  expect(states().at(-1)).toBe("idle");
});

test("V1 reselecting an aborted request does not resurrect it or poll completed tools", async () => {
  const tui = familyApi();
  tui.permissions.push({ id: "p", sessionID: "child", tool: { messageID: "m", callID: "call" } });
  tui.messages.set("m", { parts: [{ type: "tool", callID: "call", state: { status: "error" } }] });
  await (await loadPlugin()).tui(tui.api);
  await flushReports();
  tui.select("other");
  tui.emit("session.updated", { info: { id: "other" } });
  await flushReports();
  tui.select("root");
  tui.emit("session.updated", { info: { id: "root" } });
  await flushReports();
  expect(states()).not.toContain("blocked");
  const reads = tui.calls.length;
  await new Promise((resolve) => setTimeout(resolve, 650));
  expect(tui.calls).toHaveLength(reads);
});

test("V1 home and selected-session deletion settle authority and retry a dropped idle report", async () => {
  for (const action of ["home", "delete"]) {
    const tui = familyApi();
    tui.statuses.root = { type: "busy" };
    await (await loadPlugin()).tui(tui.api);
    await flushReports();
    expect(states().at(-1)).toBe("working");
    failConnections = true;
    if (action === "home") {
      tui.home();
      tui.emit("session.updated", { info: { id: "root" } });
    } else tui.emit("session.deleted", { info: { id: "root" } });
    await flushReports();
    failConnections = false;
    await new Promise((resolve) => setTimeout(resolve, 650));
    expect(states().at(-1)).toBe("idle");
    tui.dispose();
  }
});

test("V1 a delayed home settlement cannot overwrite the next selected session", async () => {
  const tui = familyApi();
  tui.statuses.root = { type: "busy" };
  await (await loadPlugin()).tui(tui.api);
  await flushReports();
  requests.length = 0;
  holdConnections = true;
  tui.home();
  tui.emit("session.updated", { info: { id: "root" } });
  await flushReports();
  expect(connections.length).toBeGreaterThan(0);
  tui.select("other");
  tui.emit("session.updated", { info: { id: "other" } });
  holdConnections = false;
  for (const connect of connections.splice(0)) connect();
  await flushReports();
  expect(requests.length).toBeGreaterThan(0);
  expect(requests.every((r) => requestParam(r, "agent_session_id") === "other")).toBe(true);
  expect(states().at(-1)).toBe("idle");
});

test("V2 ignores events without data", async () => {
  const plugin = await loadPlugin();
  const tui = v2Api();
  const dispose = await plugin.setup(tui.api);
  activeDisposers.push(dispose);
  await flushReports();
  requests.length = 0;
  expect(() => tui.emit("legacy.event")).not.toThrow();
  tui.emit("session.execution.started", { sessionID: "a" });
  await flushReports();
  expect(states()).toEqual(["working"]);
});

test("V2 completes and interrupts without legacy idle events", async () => {
  for (const terminal of ["succeeded", "interrupted", "failed"]) {
    const plugin = await loadPlugin();
    const tui = v2Api();
    const dispose = await plugin.setup(tui.api);
    activeDisposers.push(dispose);
    await flushReports();
    requests.length = 0;
    tui.emit("session.execution.started", { sessionID: "a" });
    tui.emit(`session.execution.${terminal}`, { sessionID: "a" });
    await flushReports();
    expect(states()).toEqual(["working", terminal === "failed" ? "blocked" : "idle"]);
    dispose();
  }
});

test("V2 aggregates root and child blockers and ignores other roots and child completion", async () => {
  const plugin = await loadPlugin();
  const tui = v2Api();
  const dispose = await plugin.setup(tui.api);
  activeDisposers.push(dispose);
  await flushReports();
  requests.length = 0;
  tui.emit("session.execution.started", { sessionID: "a" });
  tui.emit("permission.asked", { sessionID: "a", id: "permission-a" });
  tui.emit("form.created", { form: { sessionID: "child", id: "form-child" } });
  tui.emit("permission.replied", { sessionID: "a", requestID: "permission-a" });
  tui.emit("session.execution.succeeded", { sessionID: "child" });
  tui.emit("session.execution.started", { sessionID: "b" });
  tui.emit("permission.asked", { sessionID: "b", id: "other" });
  await flushReports();
  expect(states().at(-1)).toBe("blocked");
  expect(requests.every((r) => requestParam(r, "agent_session_id") === "a")).toBe(true);
  tui.emit("form.cancelled", { sessionID: "child", id: "form-child" });
  tui.emit("session.execution.succeeded", { sessionID: "a" });
  await flushReports();
  expect(states().slice(-2)).toEqual(["working", "idle"]);
});

test("V2 discards queued reports after selection changes and stops on disposal", async () => {
  const plugin = await loadPlugin();
  const tui = v2Api();
  const dispose = await plugin.setup(tui.api);
  activeDisposers.push(dispose);
  await flushReports();
  requests.length = 0;
  tui.emit("session.execution.started", { sessionID: "a" });
  tui.select("b");
  tui.emit("session.execution.started", { sessionID: "b" });
  await flushReports();
  expect(requests.every((r) => requestParam(r, "agent_session_id") === "b")).toBe(true);
  requests.length = 0;
  tui.emit("session.execution.succeeded", { sessionID: "b" });
  tui.home();
  await new Promise((resolve) => setTimeout(resolve, 150));
  expect(states().at(-1)).toBe("idle");
  expect(requests.every((r) => requestParam(r, "agent_session_id") === "b")).toBe(true);
  requests.length = 0;
  dispose();
  expect(tui.listeners.size).toBe(0);
  tui.select("a");
  await new Promise((resolve) => setTimeout(resolve, 250));
  expect(requests).toHaveLength(0);
});

test("V2 reconciles late blocker hydration without reviving an already-replied request", async () => {
  const plugin = await loadPlugin();
  const tui = v2Api();
  const dispose = await plugin.setup(tui.api);
  activeDisposers.push(dispose);
  await flushReports();
  tui.permissions.set("child", [{ id: "late" }]);
  await waitForStateReport();
  expect(states().at(-1)).toBe("blocked");
  tui.emit("permission.replied", { sessionID: "child", requestID: "late" });
  await waitForStateReport();
  expect(states().at(-1)).toBe("idle");
  tui.permissions.set("child", []);
  tui.forms.set("child", [{ id: "second" }]);
  await waitForStateReport();
  expect(states().at(-1)).toBe("blocked");
  tui.sessions.delete("child");
  tui.emit("session.deleted", { sessionID: "child" });
  await flushReports();
  expect(states().at(-1)).toBe("idle");
});

test("V2 never writes a delayed connection after disposal or a session switch", async () => {
  for (const action of ["dispose", "switch"]) {
    const plugin = await loadPlugin();
    const tui = v2Api();
    holdConnections = true;
    requests.length = 0;
    const dispose = await plugin.setup(tui.api);
    activeDisposers.push(dispose);
    await flushReports();
    expect(connections.length).toBeGreaterThan(0);
    if (action === "dispose") dispose();
    else tui.select("b");
    holdConnections = false;
    for (const connect of connections.splice(0)) connect();
    await flushReports();
    expect(requests).toHaveLength(0);
    dispose();
  }
});

test("V2 settles a connection that never completes", async () => {
  const plugin = await loadPlugin();
  const tui = v2Api();
  holdConnections = true;
  const dispose = await plugin.setup(tui.api);
  activeDisposers.push(dispose);
  const started = Date.now();
  while (connections.length <= 1 && Date.now() - started < 2_000) {
    await new Promise((resolve) => setTimeout(resolve, 25));
  }
  expect(connections.length).toBeGreaterThan(1);
  dispose();
});

test("V2 resends the latest state after a failed delivery", async () => {
  const plugin = await loadPlugin();
  const tui = v2Api();
  const dispose = await plugin.setup(tui.api);
  activeDisposers.push(dispose);
  await flushReports();
  // Exhaust the selection retry schedule so only the event report remains.
  await new Promise((resolve) => setTimeout(resolve, 1_600));
  requests.length = 0;
  tui.emit("session.execution.started", { sessionID: "a" });
  await flushReports();
  failConnections = true;
  tui.emit("session.execution.succeeded", { sessionID: "a" });
  const resend = waitForStateReport();
  await new Promise((resolve) => setTimeout(resolve, 700));
  failConnections = false;
  await resend;
  expect(states().at(-1)).toBe("idle");
  dispose();
});

test("V2 reconciles activity hydrated after selection and after reconnect", async () => {
  const tui = v2Api();
  const dispose = (await loadPlugin()).setup(tui.api);
  activeDisposers.push(dispose);
  await flushReports();
  expect(states().at(-1)).toBe("idle");
  tui.statuses.set("a", "running");
  await new Promise((resolve) => setTimeout(resolve, 150));
  expect(states().at(-1)).toBe("working");
  tui.emit("server.connected");
  tui.statuses.set("a", "idle");
  await new Promise((resolve) => setTimeout(resolve, 150));
  expect(states().at(-1)).toBe("idle");
});

test("V2 keeps a pane working until all background descendants finish", async () => {
  const tui = v2Api();
  tui.sessions.set("grandchild", { id: "grandchild", parentID: "child" });
  const dispose = (await loadPlugin()).setup(tui.api);
  activeDisposers.push(dispose);
  await flushReports();
  tui.emit("session.execution.started", { sessionID: "a" });
  tui.emit("session.execution.started", { sessionID: "child" });
  tui.emit("session.execution.started", { sessionID: "grandchild" });
  tui.emit("session.execution.succeeded", { sessionID: "a" });
  await flushReports();
  expect(states().at(-1)).toBe("working");
  tui.emit("session.execution.succeeded", { sessionID: "child" });
  await flushReports();
  expect(states().at(-1)).toBe("working");
  tui.emit("session.execution.interrupted", { sessionID: "grandchild" });
  await flushReports();
  expect(states().at(-1)).toBe("idle");
  expect(requests.every((r) => requestParam(r, "agent_session_id") === "a")).toBe(true);
});

test("V2 hydrates an already-running child without execution events", async () => {
  const tui = v2Api();
  tui.statuses.set("child", "running");
  const dispose = (await loadPlugin()).setup(tui.api);
  activeDisposers.push(dispose);
  await flushReports();
  expect(states().at(-1)).toBe("working");
  tui.statuses.set("child", "idle");
  await new Promise((resolve) => setTimeout(resolve, 150));
  expect(states().at(-1)).toBe("idle");
});

test("V2 preserves execution deltas over stale activity snapshots", async () => {
  const tui = v2Api();
  const dispose = (await loadPlugin()).setup(tui.api);
  activeDisposers.push(dispose);
  await flushReports();
  tui.emit("session.execution.started", { sessionID: "child" });
  await new Promise((resolve) => setTimeout(resolve, 150));
  expect(states().at(-1)).toBe("working");
  tui.statuses.set("child", "running");
  await new Promise((resolve) => setTimeout(resolve, 150));
  tui.emit("session.execution.succeeded", { sessionID: "child" });
  await new Promise((resolve) => setTimeout(resolve, 150));
  expect(states().at(-1)).toBe("idle");
  tui.statuses.set("child", "idle");
  tui.sessions.set("child", { id: "child", parentID: "a", outcome: "succeeded" });
  await new Promise((resolve) => setTimeout(resolve, 150));
  expect(states().at(-1)).toBe("idle");
});

test("V2 prioritizes real blockers but does not latch a failed child", async () => {
  const tui = v2Api();
  const dispose = (await loadPlugin()).setup(tui.api);
  activeDisposers.push(dispose);
  await flushReports();
  tui.emit("session.execution.started", { sessionID: "child" });
  tui.emit("permission.asked", { sessionID: "child", id: "p" });
  tui.emit("form.created", { form: { sessionID: "a", id: "f" } });
  tui.emit("permission.replied", { sessionID: "child", requestID: "p" });
  await flushReports();
  expect(states().at(-1)).toBe("blocked");
  tui.emit("form.replied", { sessionID: "a", id: "f" });
  await flushReports();
  expect(states().at(-1)).toBe("working");
  tui.emit("session.execution.failed", { sessionID: "child" });
  await flushReports();
  expect(states().at(-1)).toBe("idle");
  tui.emit("session.execution.started", { sessionID: "a" });
  await flushReports();
  expect(states().at(-1)).toBe("working");
});

test("V2 child failure leaves a running parent working and settles after parent completion", async () => {
  const tui = v2Api();
  const dispose = (await loadPlugin()).setup(tui.api);
  activeDisposers.push(dispose);
  await flushReports();
  requests.length = 0;
  tui.emit("session.execution.started", { sessionID: "a" });
  tui.emit("session.execution.started", { sessionID: "child" });
  tui.emit("session.execution.failed", { sessionID: "child" });
  await new Promise((resolve) => setTimeout(resolve, 150));
  expect(states().at(-1)).toBe("working");
  tui.emit("session.execution.succeeded", { sessionID: "a" });
  await new Promise((resolve) => setTimeout(resolve, 150));
  expect(states().at(-1)).toBe("idle");
  expect(states()).not.toContain("blocked");
});

test("V2 a failed grandchild cannot block a running sibling", async () => {
  const tui = v2Api();
  tui.sessions.set("sibling", { id: "sibling", parentID: "a" });
  tui.sessions.set("grandchild", { id: "grandchild", parentID: "child" });
  const dispose = (await loadPlugin()).setup(tui.api);
  activeDisposers.push(dispose);
  await flushReports();
  requests.length = 0;
  tui.emit("session.execution.started", { sessionID: "sibling" });
  tui.emit("session.execution.started", { sessionID: "grandchild" });
  tui.emit("session.execution.failed", { sessionID: "grandchild" });
  await flushReports();
  expect(states().at(-1)).toBe("working");
  tui.emit("session.execution.succeeded", { sessionID: "sibling" });
  await flushReports();
  expect(states().at(-1)).toBe("idle");
  expect(states()).not.toContain("blocked");
});

test("V2 child failures preserve pending permissions and forms until replies", async () => {
  const tui = v2Api();
  const dispose = (await loadPlugin()).setup(tui.api);
  activeDisposers.push(dispose);
  await flushReports();
  tui.emit("session.execution.started", { sessionID: "a" });
  tui.emit("permission.asked", { sessionID: "child", id: "p" });
  tui.emit("form.created", { form: { sessionID: "child", id: "f" } });
  tui.emit("session.execution.failed", { sessionID: "child" });
  await flushReports();
  expect(states().at(-1)).toBe("blocked");
  tui.emit("permission.replied", { sessionID: "child", requestID: "p" });
  await flushReports();
  expect(states().at(-1)).toBe("blocked");
  tui.emit("form.replied", { sessionID: "child", id: "f" });
  await flushReports();
  expect(states().at(-1)).toBe("working");
});

test("V2 acknowledges failed child deltas and observes later cached retries", async () => {
  const tui = v2Api();
  tui.statuses.set("child", "running");
  const dispose = (await loadPlugin()).setup(tui.api);
  activeDisposers.push(dispose);
  await flushReports();
  requests.length = 0;
  tui.emit("session.execution.failed", { sessionID: "child" });
  await new Promise((resolve) => setTimeout(resolve, 150));
  expect(states().at(-1)).toBe("idle");
  // Starting the parent must not revive the child's stale running snapshot.
  tui.emit("session.execution.started", { sessionID: "a" });
  tui.emit("session.execution.succeeded", { sessionID: "a" });
  await new Promise((resolve) => setTimeout(resolve, 150));
  expect(states().at(-1)).toBe("idle");
  tui.statuses.set("child", "idle");
  tui.sessions.set("child", { id: "child", parentID: "a", outcome: "failed" });
  await new Promise((resolve) => setTimeout(resolve, 150));
  expect(states().at(-1)).toBe("idle");
  // Cache acknowledgement releases the delta, so a missed retry event is safe.
  tui.statuses.set("child", "running");
  await new Promise((resolve) => setTimeout(resolve, 150));
  expect(states().at(-1)).toBe("working");
  tui.emit("session.execution.failed", { sessionID: "child" });
  tui.emit("session.execution.started", { sessionID: "child" });
  await flushReports();
  expect(states().at(-1)).toBe("working");
  expect(states()).not.toContain("blocked");
});

test("V2 reconnect hydrates child retries after failures without hiding root failures", async () => {
  const tui = v2Api();
  const dispose = (await loadPlugin()).setup(tui.api);
  activeDisposers.push(dispose);
  await flushReports();
  tui.emit("session.execution.failed", { sessionID: "child" });
  await flushReports();
  expect(states().at(-1)).toBe("idle");
  tui.statuses.set("child", "running");
  tui.emit("server.connected");
  await new Promise((resolve) => setTimeout(resolve, 150));
  expect(states().at(-1)).toBe("working");
  expect(states()).not.toContain("blocked");
  tui.emit("session.execution.failed", { sessionID: "a" });
  tui.emit("server.connected");
  await flushReports();
  expect(states().at(-1)).toBe("blocked");
  tui.emit("session.execution.started", { sessionID: "a" });
  await flushReports();
  expect(states().at(-1)).toBe("working");
});

test("V2 switching sessions or selecting a child does not revive child failures", async () => {
  const tui = v2Api();
  const dispose = (await loadPlugin()).setup(tui.api);
  activeDisposers.push(dispose);
  await flushReports();
  requests.length = 0;
  tui.emit("session.execution.failed", { sessionID: "child" });
  tui.sessions.set("child", { id: "child", parentID: "a", outcome: "failed" });
  tui.select("b");
  tui.emit("session.execution.started", { sessionID: "b" });
  await flushReports();
  expect(states().at(-1)).toBe("working");
  tui.select("child");
  tui.emit("session.execution.succeeded", { sessionID: "a" });
  await flushReports();
  expect(states().at(-1)).toBe("idle");
  expect(requestParam(requests.at(-1), "agent_session_id")).toBe("a");
  expect(states()).not.toContain("blocked");
});

test("V2 ignores historical child failures but hydrates the selected root failure", async () => {
  const tui = v2Api();
  tui.sessions.set("child", { id: "child", parentID: "a", outcome: "failed" });
  tui.sessions.set("a", { id: "a", outcome: "failed" });
  const dispose = (await loadPlugin()).setup(tui.api);
  activeDisposers.push(dispose);
  await flushReports();
  expect(states().at(-1)).toBe("blocked");
  tui.emit("session.execution.started", { sessionID: "a" });
  await flushReports();
  expect(states().at(-1)).toBe("working");
  tui.emit("session.execution.succeeded", { sessionID: "a" });
  await new Promise((resolve) => setTimeout(resolve, 150));
  expect(states().at(-1)).toBe("idle");
});

test("V2 settles a working or blocked pane on home and retries failed settlement", async () => {
  for (const block of [false, true]) {
    const tui = v2Api();
    const dispose = (await loadPlugin()).setup(tui.api);
    activeDisposers.push(dispose);
    await flushReports();
    tui.emit("session.execution.started", { sessionID: "a" });
    if (block) tui.emit("permission.asked", { sessionID: "child", id: "p" });
    await flushReports();
    expect(states().at(-1)).toBe(block ? "blocked" : "working");
    failConnections = true;
    tui.home();
    tui.emit("session.execution.succeeded", { sessionID: "a" });
    await flushReports();
    failConnections = false;
    await new Promise((resolve) => setTimeout(resolve, 650));
    expect(states().at(-1)).toBe("idle");
    dispose();
  }
});

test("V2 delayed home settlement cannot overwrite a newly selected session", async () => {
  const tui = v2Api();
  const dispose = (await loadPlugin()).setup(tui.api);
  activeDisposers.push(dispose);
  await flushReports();
  tui.emit("session.execution.started", { sessionID: "a" });
  await flushReports();
  holdConnections = true;
  requests.length = 0;
  tui.home();
  tui.emit("session.execution.succeeded", { sessionID: "a" });
  await flushReports();
  expect(connections.length).toBeGreaterThan(0);
  tui.select("b");
  tui.emit("session.execution.started", { sessionID: "b" });
  holdConnections = false;
  for (const connect of connections.splice(0)) connect();
  await flushReports();
  expect(requests.length).toBeGreaterThan(0);
  expect(requests.every((r) => requestParam(r, "agent_session_id") === "b")).toBe(true);
  expect(states().at(-1)).toBe("working");
});

test("V2 rejects stale writes across A/B/A navigation", async () => {
  const tui = v2Api();
  const dispose = (await loadPlugin()).setup(tui.api);
  activeDisposers.push(dispose);
  await flushReports();
  requests.length = 0;
  holdConnections = true;
  tui.emit("session.execution.started", { sessionID: "a" });
  await flushReports();
  tui.select("b");
  tui.emit("session.execution.started", { sessionID: "b" });
  tui.select("a");
  tui.emit("session.execution.succeeded", { sessionID: "a" });
  holdConnections = false;
  for (const connect of connections.splice(0)) connect();
  await flushReports();
  expect(states()).not.toContain("working");
  expect(requests.every((r) => requestParam(r, "agent_session_id") === "a")).toBe(true);
});

test("V2 deletion settles root activity and removes active-child blockers", async () => {
  const tui = v2Api();
  const dispose = (await loadPlugin()).setup(tui.api);
  activeDisposers.push(dispose);
  await flushReports();
  tui.emit("session.execution.started", { sessionID: "child" });
  tui.emit("permission.asked", { sessionID: "child", id: "p" });
  await flushReports();
  expect(states().at(-1)).toBe("blocked");
  tui.emit("session.deleted", { sessionID: "child" });
  await flushReports();
  expect(states().at(-1)).toBe("idle");
  tui.emit("session.execution.started", { sessionID: "a" });
  await flushReports();
  tui.emit("session.deleted", { sessionID: "a" });
  await flushReports();
  expect(states().at(-1)).toBe("idle");
});

test("V2 disposal cancels pending home-settlement retries", async () => {
  const tui = v2Api();
  const dispose = (await loadPlugin()).setup(tui.api);
  activeDisposers.push(dispose);
  await flushReports();
  tui.emit("session.execution.started", { sessionID: "a" });
  await flushReports();
  failConnections = true;
  tui.home();
  tui.emit("session.execution.succeeded", { sessionID: "a" });
  await flushReports();
  dispose();
  failConnections = false;
  requests.length = 0;
  tui.select("b");
  await new Promise((resolve) => setTimeout(resolve, 650));
  expect(requests).toHaveLength(0);
  expect(tui.listeners.size).toBe(0);
});

test("V2 failed delivery uses retry backoff instead of retrying on every route poll", async () => {
  const tui = v2Api();
  const dispose = (await loadPlugin()).setup(tui.api);
  activeDisposers.push(dispose);
  await new Promise((resolve) => setTimeout(resolve, 1600));
  tui.emit("session.execution.started", { sessionID: "a" });
  await flushReports();
  const previous = connectionAttempts;
  failConnections = true;
  tui.home();
  tui.emit("session.execution.succeeded", { sessionID: "a" });
  await new Promise((resolve) => setTimeout(resolve, 200));
  expect(connectionAttempts - previous).toBe(1);
  failConnections = false;
  await new Promise((resolve) => setTimeout(resolve, 450));
  expect(states().at(-1)).toBe("idle");
});

test("V2 deleting an ancestor cannot retain a descendant's stale blocker", async () => {
  const tui = v2Api();
  tui.sessions.set("grandchild", { id: "grandchild", parentID: "child" });
  const dispose = (await loadPlugin()).setup(tui.api);
  activeDisposers.push(dispose);
  await flushReports();
  tui.emit("permission.asked", { sessionID: "grandchild", id: "p" });
  await flushReports();
  expect(states().at(-1)).toBe("blocked");
  tui.emit("session.deleted", { sessionID: "child" });
  await new Promise((resolve) => setTimeout(resolve, 150));
  expect(states().at(-1)).toBe("idle");
});

test("V2 reconnect discards old activity deltas but preserves new execution events", async () => {
  const tui = v2Api();
  const dispose = (await loadPlugin()).setup(tui.api);
  activeDisposers.push(dispose);
  await flushReports();
  tui.emit("session.execution.started", { sessionID: "a" });
  await flushReports();
  expect(states().at(-1)).toBe("working");
  tui.emit("server.connected");
  tui.sessions.set("a", { id: "a", outcome: "succeeded" });
  await new Promise((resolve) => setTimeout(resolve, 150));
  expect(states().at(-1)).toBe("idle");
  tui.emit("session.execution.started", { sessionID: "child" });
  await new Promise((resolve) => setTimeout(resolve, 150));
  expect(states().at(-1)).toBe("working");
});
