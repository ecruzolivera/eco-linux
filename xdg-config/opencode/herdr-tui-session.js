// installed by herdr
// managed by herdr; reinstalling or updating the integration overwrites this file.
// HERDR_INTEGRATION_ID=opencode-tui
// HERDR_INTEGRATION_VERSION=13
// Local V2 reliability patch: ~/.local/share/herdr-opencode-fix
// Reapply the recorded patch after a Herdr integration update.

import net from "node:net";

const SOURCE = "herdr:opencode";
const AGENT = "opencode";
const ROUTE_POLL_INTERVAL_MS = 100;
const SELECTION_RETRY_DELAYS_MS = [100, 400, 1_000];

function requestOnce(sessionID, state, seq, isCurrent = () => true) {
  const paneId = process.env.HERDR_PANE_ID;
  const socketPath = process.env.HERDR_SOCKET_PATH;
  if (!paneId || !socketPath) {
    return Promise.resolve(true);
  }

  const socketEndpoint =
    process.platform === "win32" ? `\\\\.\\pipe\\${socketPath}` : socketPath;
  const request = {
    id: `${SOURCE}:tui:${Date.now()}:${Math.floor(Math.random() * 1_000_000)
      .toString()
      .padStart(6, "0")}`,
    method: state === undefined ? "pane.report_agent_session" : "pane.report_agent",
    params: {
      pane_id: paneId,
      source: SOURCE,
      agent: AGENT,
      agent_session_id: sessionID,
      ...(state === undefined ? { session_start_source: "select" } : { state, seq }),
    },
  };

  return new Promise((resolve) => {
    let settled = false;
    let timer;
    const settle = (delivered) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      client.destroy();
      resolve(delivered);
    };
    const client = net.createConnection(socketEndpoint, () => {
      if (!isCurrent()) {
        settle(false);
        return;
      }
      client.write(`${JSON.stringify(request)}\n`);
    });

    // A plain timer, not socket.setTimeout, so a connection that never finishes
    // connecting still settles and cannot block later reports behind the queue.
    timer = setTimeout(() => settle(false), 500);
    timer.unref?.();
    client.on("data", () => settle(true));
    client.on("error", () => settle(false));
    client.on("end", () => settle(false));
    client.on("close", () => settle(false));
  });
}

export default {
  id: "herdr.opencode.session-selection",
  // Keep this plain object dependency-free: V1 and V2 expose different SDK
  // packages, but both loaders accept their own lifecycle entry on this object.
  setup,
  tui,
};

async function tui(api) {
  if (process.env.HERDR_ENV !== "1" || !process.env.HERDR_SOCKET_PATH || !process.env.HERDR_PANE_ID) return;

  let disposed = false;
  let context;
  let sequence = Date.now() * 1000;
  let chain = Promise.resolve();

  function routeID() {
    const route = api.route.current;
    return route?.name === "session" ? route.params?.sessionID : undefined;
  }

  function current(ctx) {
    return !disposed && context === ctx && routeID() === ctx.route;
  }

  async function read(ctx, request) {
    const result = await request({
      signal: AbortSignal.any([ctx.controller.signal, AbortSignal.timeout(5_000)]),
      throwOnError: true,
    });
    if (!current(ctx) || result?.data === undefined) throw new Error("session data unavailable");
    return result.data;
  }

  // The first selected session owns this pane's subtree. Browsing descendants
  // keeps that boundary; directly attaching to a child does not claim siblings.
  function root(ctx, id) {
    const seen = new Set();
    while (typeof id === "string" && !seen.has(id) && !ctx.deleted.has(id)) {
      seen.add(id);
      if (id === ctx.boundary) return id;
      const session = ctx.sessions.get(id) ?? api.state.session.get(id);
      if (!session) return;
      if (!session.parentID) return id;
      id = session.parentID;
    }
  }

  async function resolveRoot(ctx, id) {
    const seen = new Set();
    while (typeof id === "string" && !seen.has(id) && !ctx.deleted.has(id)) {
      seen.add(id);
      if (id === ctx.boundary) return id;
      let session = ctx.sessions.get(id) ?? api.state.session.get(id);
      if (!session) {
        if (!ctx.lookups.has(id)) {
          const requestedID = id;
          const lookup = read(ctx, (options) => api.client.session.get({ sessionID: requestedID }, options));
          ctx.lookups.set(id, lookup);
          lookup.finally(() => ctx.lookups.delete(requestedID)).catch(() => {});
        }
        session = await ctx.lookups.get(id);
        if (ctx.deleted.has(id)) return;
        session = ctx.sessions.get(id) ?? session;
        if (session.id !== id) throw new Error("unexpected session identity");
        ctx.sessions.set(id, session);
      }
      if (!session.parentID) return id;
      id = session.parentID;
    }
  }

  function owners(ctx) {
    return new Set([...ctx.statuses.keys(), ...[...ctx.blockers.values()].map((r) => r.sessionID)]);
  }

  function state(ctx) {
    if (ctx.settled) return "idle";
    for (const request of ctx.blockers.values()) {
      if (root(ctx, request.sessionID) === ctx.selected) return "blocked";
    }
    if (ctx.errors.has(ctx.selected)) return "blocked";
    for (const id of ctx.statuses.keys()) {
      if (root(ctx, id) === ctx.selected) return "working";
    }
    if (ctx.hydrated && [...owners(ctx)].every((id) => root(ctx, id) !== undefined)) return "idle";
  }

  function publish(ctx, selection = false) {
    if (!current(ctx) || !ctx.selected) return;
    ctx.selectionPending ||= selection;
    if (ctx.queued) return;
    ctx.queued = true;
    chain = chain.then(async () => {
      ctx.queued = false;
      const selected = ctx.selected;
      const isCurrent = () => current(ctx) && !!selected && ctx.selected === selected &&
        (ctx.settled || root(ctx, ctx.route) === selected);
      if (!isCurrent()) return;
      if (ctx.selectionPending) {
        if (!await requestOnce(selected, undefined, undefined, isCurrent)) {
          ctx.retryAt = Date.now() + 500;
          return;
        }
        if (!isCurrent()) return;
        ctx.selectionPending = false;
        ctx.lastState = undefined;
      }
      const value = state(ctx);
      if (value === undefined || value === ctx.lastState) return;
      const delivered = await requestOnce(selected, value, ++sequence, isCurrent);
      if (!isCurrent()) return;
      ctx.lastState = delivered ? value : undefined;
      if (!delivered) ctx.retryAt = Date.now() + 500;
    }).catch(() => {
      if (current(ctx)) {
        ctx.lastState = undefined;
        ctx.retryAt = Date.now() + 500;
      }
    });
  }

  function retire(ctx, route) {
    ctx?.controller?.abort();
    context = ctx?.selected
      ? { route, selected: ctx.selected, settled: true, retryAt: Infinity }
      : undefined;
    if (context) publish(context);
  }

  function reconcile(ctx) {
    if (!current(ctx)) return;
    publish(ctx);
    if (ctx.resolving) {
      ctx.resolveAgain = true;
      return;
    }
    ctx.resolving = true;
    void (async () => {
      const ancestor = await resolveRoot(ctx, ctx.route);
      if (!current(ctx) || !ancestor) return;
      const selected = ancestor === ctx.boundary ? ctx.boundary : ctx.route;
      if (selected !== ctx.selected) {
        ctx.boundary = selected;
        ctx.selected = selected;
        publish(ctx, true);
      }
      // Fetch ancestry only for active/request-bearing sessions, not historical trees.
      await Promise.all([...owners(ctx)].map((id) => resolveRoot(ctx, id)));
      if (current(ctx)) publish(ctx);
    })().catch(() => {
      if (current(ctx)) ctx.retryAt = Date.now() + 500;
    }).finally(() => {
      ctx.resolving = false;
      if (ctx.resolveAgain) {
        ctx.resolveAgain = false;
        reconcile(ctx);
      }
    });
  }

  function clearRequests(ctx, matches) {
    for (const [key, request] of ctx.blockers) if (matches(request)) ctx.blockers.delete(key);
  }

  function terminalTool(part) {
    return part?.type === "tool" && ["completed", "error"].includes(part.state?.status);
  }

  function apply(ctx, event) {
    const data = event.properties;
    if (!data) return;
    if (event.type === "message.part.updated") {
      const part = data.part;
      if (terminalTool(part)) {
        clearRequests(ctx, (r) => r.sessionID === part.sessionID &&
          r.tool?.messageID === part.messageID && r.tool?.callID === part.callID);
      }
      return;
    }
    const id = data.sessionID ?? data.info?.id;
    if (typeof id !== "string" || ctx.deleted.has(id)) return;
    switch (event.type) {
      case "session.created":
      case "session.updated":
        if (data.info) ctx.sessions.set(id, data.info);
        break;
      case "session.deleted":
        ctx.deleted.add(id);
        ctx.sessions.delete(id);
        ctx.statuses.delete(id);
        ctx.errors.delete(id);
        clearRequests(ctx, (r) => r.sessionID === id);
        if (ctx.selected === id) retire(ctx, ctx.route);
        break;
      case "session.status":
      case "session.idle": {
        const status = event.type === "session.idle" ? "idle" : data.status?.type;
        if (status === "busy" || status === "retry") {
          ctx.statuses.set(id, status);
          ctx.errors.delete(id);
        } else if (status === "idle") {
          ctx.statuses.delete(id);
          ctx.errors.delete(id);
        }
        break;
      }
      case "session.error":
        if (data.error?.name !== "MessageAbortedError") ctx.errors.add(id);
        break;
      case "permission.asked":
      case "question.asked":
        if (typeof data.id === "string") ctx.blockers.set(`${event.type.split(".")[0]}:${data.id}`, data);
        break;
      case "permission.replied":
      case "question.replied":
      case "question.rejected":
        ctx.blockers.delete(`${event.type.split(".")[0]}:${data.requestID}`);
        break;
    }
  }

  async function hydrate(ctx) {
    if (!current(ctx) || ctx.loading) return;
    ctx.loading = true;
    try {
      const [statuses, permissions, questions] = await Promise.all([
        read(ctx, (options) => api.client.session.status(undefined, options)),
        read(ctx, (options) => api.client.permission.list(undefined, options)),
        read(ctx, (options) => api.client.question.list(undefined, options)),
      ]);
      if (!statuses || typeof statuses !== "object" || Array.isArray(statuses) ||
          !Object.values(statuses).every((s) => ["busy", "retry", "idle"].includes(s?.type)) ||
          !Array.isArray(permissions) || !Array.isArray(questions)) {
        throw new Error("incomplete session snapshot");
      }
      const messages = new Map();
      const blockers = new Map();
      let validated = true;
      await Promise.all([["permission", permissions], ["question", questions]].flatMap(([kind, requests]) =>
        requests.map(async (request) => {
          if (ctx.deleted.has(request.sessionID)) return;
          if (request.tool) {
            const { messageID, callID } = request.tool;
            const key = `${request.sessionID}:${messageID}`;
            if (!messages.has(key)) messages.set(key, read(ctx, (options) => api.client.session.message({
              sessionID: request.sessionID, messageID,
            }, options)));
            try {
              const message = await messages.get(key);
              const part = message.parts?.find((p) => p.type === "tool" && p.callID === callID);
              // OpenCode can retain pending requests after abort. Status alone is
              // insufficient: the same session may already be running a new turn.
              if (terminalTool(part)) return;
            } catch {
              validated = false;
            }
          }
          if (!ctx.deleted.has(request.sessionID)) blockers.set(`${kind}:${request.id}`, request);
        })));
      if (!current(ctx)) return;
      ctx.statuses = new Map(Object.entries(statuses)
        .filter(([id, status]) => !ctx.deleted.has(id) && (status.type === "busy" || status.type === "retry")));
      ctx.blockers = blockers;
      // Preserve deltas until hydration succeeds, including retry backoff:
      // a later snapshot must not revive a replied or cancelled request.
      for (const event of ctx.events) apply(ctx, event);
      ctx.hydrated = validated;
      if (!validated) ctx.retryAt = Date.now() + 500;
      reconcile(ctx);
    } catch {
      if (current(ctx)) ctx.retryAt = Date.now() + 500;
    } finally {
      ctx.loading = false;
      if (ctx.hydrated) ctx.events = [];
    }
  }

  function syncSelection(reset = false) {
    if (disposed) return;
    const id = routeID();
    if (reset || id !== context?.route) {
      if (typeof id !== "string" || !id) {
        retire(context, id);
        return;
      }
      const boundary = context?.settled ? undefined : context?.selected;
      context?.controller?.abort();
      const ctx = {
        route: id, boundary, controller: new AbortController(), sessions: new Map(), lookups: new Map(),
        statuses: new Map(), blockers: new Map(), errors: new Set(), deleted: new Set(),
        events: [], hydrated: false, loading: false, resolving: false,
        retryAt: Infinity, selectionAt: 0, retryIndex: 0,
      };
      context = ctx;
      reconcile(ctx);
      void hydrate(ctx);
    }
    const ctx = context;
    if (!ctx) return;
    if (!ctx.settled && ctx.selected && Date.now() >= ctx.selectionAt) {
      publish(ctx, true);
      const delay = SELECTION_RETRY_DELAYS_MS[ctx.retryIndex++];
      ctx.selectionAt = delay === undefined ? Infinity : Date.now() + delay;
    }
    if (Date.now() >= ctx.retryAt) {
      ctx.retryAt = Infinity;
      if (ctx.settled) publish(ctx);
      else {
        if (!ctx.hydrated) void hydrate(ctx);
        reconcile(ctx);
      }
    }
  }

  const subscriptions = [
    "session.created", "session.updated", "session.deleted", "session.status", "session.idle", "session.error",
    "permission.asked", "permission.replied", "question.asked", "question.replied", "question.rejected",
    "message.part.updated",
  ].map((type) => api.event.on(type, (event) => {
    if (type === "message.part.updated" && !terminalTool(event.properties?.part)) return;
    syncSelection();
    const ctx = context;
    if (!ctx || ctx.settled) return;
    if (ctx.loading || !ctx.hydrated) ctx.events.push(event);
    apply(ctx, event);
    reconcile(ctx);
  }));
  for (const type of ["server.connected", "server.instance.disposed", "global.disposed"]) {
    subscriptions.push(api.event.on(type, () => syncSelection(true)));
  }
  const poll = setInterval(syncSelection, ROUTE_POLL_INTERVAL_MS);
  api.lifecycle.onDispose(() => {
    disposed = true;
    context?.controller?.abort();
    clearInterval(poll);
    for (const unsubscribe of subscriptions) unsubscribe();
  });
  syncSelection();
}

function setup(api) {
  if (process.env.HERDR_ENV !== "1" || !process.env.HERDR_SOCKET_PATH || !process.env.HERDR_PANE_ID) return;

  let disposed = false;
  let selected;
  let generation = 0;
  let sequence = Date.now() * 1000;
  let chain = Promise.resolve();
  let retryIndex = 0;
  let nextSelectionAt = 0;
  let settlement;
  let lastQueuedState;
  let retryTimer;
  const sessions = new Map();
  const deleted = new Set();
  const activityChanges = new Map();
  let blockers = new Map();
  // Event callbacks may precede cache updates. Retain each delta until the
  // cache reflects it, so late hydration cannot undo a reply or lose an ask.
  const blockerChanges = new Map();

  function root(id) {
    const seen = new Set();
    while (typeof id === "string" && !seen.has(id) && !deleted.has(id)) {
      seen.add(id);
      const session = api.data.session.get(id) ?? sessions.get(id);
      if (!session) return;
      if (!session.parentID) return id;
      id = session.parentID;
    }
  }

  function current() {
    const route = api.ui.router.current();
    return route.type === "session" ? root(route.sessionID) : undefined;
  }

  // Selection and lifecycle use one queue. Recheck attribution at dispatch,
  // not just when receiving the event, and reject A -> B -> A stale work too.
  function enqueue(value) {
    const sessionID = selected ?? settlement;
    const revision = generation;
    const isCurrent = () => !disposed && revision === generation && !!sessionID &&
      (selected === sessionID ? current() === sessionID : settlement === sessionID && current() === undefined);
    chain = chain.then(async () => {
      if (!isCurrent()) return;
      const delivered = await requestOnce(sessionID, value, value === undefined ? undefined : ++sequence, isCurrent);
      if (!isCurrent()) return;
      if (!delivered) {
        scheduleStateRetry();
      } else if (settlement === sessionID) {
        settlement = undefined;
      }
    }).catch(() => {
      if (!isCurrent()) return;
      scheduleStateRetry();
    });
  }

  // A dropped report must not strand the pane on a stale state once the
  // selection retry schedule has run out: resend the latest state until the
  // socket accepts it or the selection is no longer current.
  function scheduleStateRetry() {
    if (disposed || retryTimer) return;
    retryTimer = setTimeout(() => {
      retryTimer = undefined;
      syncSelection();
      publish(true);
    }, 500);
    retryTimer.unref?.();
  }

  function members() {
    if (!selected) return [];
    const candidates = new Set([
      selected, ...api.data.session.family(selected), ...sessions.keys(),
      ...activityChanges.keys(), ...blockers.values(),
    ]);
    return [...candidates].filter((id) => root(id) === selected);
  }

  function reconcileActivity(id) {
    const status = api.data.session.status(id);
    const outcome = api.data.session.get(id)?.outcome;
    const change = activityChanges.get(id);
    // Keep terminal deltas until cache acknowledgement so a failed child cannot
    // appear running again. Only a failure of the selected root is actionable.
    if (change && (id !== selected || change.outcome !== "failed") && status === change.status &&
        (change.outcome === undefined || outcome === change.outcome)) {
      activityChanges.delete(id);
    }
    const pending = activityChanges.get(id);
    return {
      running: (pending?.status ?? status) === "running",
      failed: id === selected && (pending ? pending.outcome === "failed" :
        status !== "running" && outcome === "failed"),
    };
  }

  function reconcileState() {
    if (!selected) return "idle";
    const family = members().map(reconcileActivity);
    if (blockers.size || family.some((item) => item.failed)) return "blocked";
    return family.some((item) => item.running) ? "working" : "idle";
  }

  function publish(force = false) {
    if (disposed || (!selected && !settlement)) return;
    const value = reconcileState();
    if (!force && value === lastQueuedState) return;
    lastQueuedState = value;
    enqueue(value);
  }

  function changeBlocker(id, kind, requestID, present) {
    if (typeof requestID !== "string") return;
    const key = `${kind}:${requestID}`;
    blockerChanges.set(key, { id, kind, present });
    if (present) blockers.set(key, id);
    else blockers.delete(key);
  }

  function reconcileBlockers() {
    const next = new Map();
    const hydrated = new Set();
    for (const member of members()) {
      for (const kind of ["permission", "form"]) {
        const items = api.data.session[kind].list(member);
        if (items === undefined) {
          for (const [key, owner] of blockers) {
            if (owner === member && key.startsWith(`${kind}:`)) next.set(key, owner);
          }
          continue;
        }
        hydrated.add(`${kind}:${member}`);
        for (const item of items) next.set(`${kind}:${item.id}`, member);
      }
    }
    for (const [key, change] of blockerChanges) {
      if (root(change.id) !== selected) continue;
      if (hydrated.has(`${change.kind}:${change.id}`) && next.has(key) === change.present) {
        blockerChanges.delete(key);
      } else if (change.present) {
        next.set(key, change.id);
      } else {
        next.delete(key);
      }
    }
    blockers = next;
  }

  function syncSelection() {
    if (disposed) return;
    const id = current();
    if (id !== selected) {
      const previous = selected;
      selected = id;
      generation += 1;
      clearTimeout(retryTimer);
      retryTimer = undefined;
      retryIndex = 0;
      nextSelectionAt = 0;
      lastQueuedState = undefined;
      blockers.clear();
      blockerChanges.clear();
      activityChanges.clear();
      settlement = id ? undefined : previous;
    }
    if (!id) {
      publish();
      return;
    }
    reconcileBlockers();
    if (Date.now() < nextSelectionAt) {
      publish();
      return;
    }
    enqueue(undefined);
    publish(true);
    const delay = SELECTION_RETRY_DELAYS_MS[retryIndex++];
    nextSelectionAt = delay === undefined ? Number.POSITIVE_INFINITY : Date.now() + delay;
  }

  function receive({ details: event }) {
    if (disposed) return;
    if (event.type === "server.connected") {
      // Old activity deltas cannot describe executions completed or restarted
      // while disconnected. Retain only the selected root's actionable failure;
      // hydrate descendants afresh, including children that previously failed.
      for (const [id, change] of activityChanges) {
        if (id !== selected || change.outcome !== "failed") activityChanges.delete(id);
      }
      lastQueuedState = undefined;
      syncSelection();
      return;
    }
    const data = event.data;
    if (data == null) return;
    if (event.type === "session.created") {
      sessions.set(data.sessionID, { id: data.sessionID, parentID: data.parentID });
    }
    if (event.type === "session.deleted") {
      const affected = data.sessionID === selected || [...blockers.values()].includes(data.sessionID);
      deleted.add(data.sessionID);
      sessions.delete(data.sessionID);
      activityChanges.delete(data.sessionID);
      // Deletion is delivered after the cache can remove the session. Use
      // stored ownership rather than looking up the deleted child's ancestry.
      for (const [key, owner] of blockers) if (owner === data.sessionID) blockers.delete(key);
      for (const [key, change] of blockerChanges) {
        if (change.id === data.sessionID) blockerChanges.delete(key);
      }
      syncSelection();
      if (selected && affected) publish();
      return;
    }
    syncSelection();
    const id = event.type === "form.created" ? data.form.sessionID : data.sessionID;
    if (!selected || root(id) !== selected) return;
    switch (event.type) {
      case "permission.asked":
        changeBlocker(id, "permission", data.id, true);
        break;
      case "permission.replied":
        changeBlocker(id, "permission", data.requestID, false);
        break;
      case "form.created":
        changeBlocker(id, "form", data.form.id, true);
        break;
      case "form.replied":
      case "form.cancelled":
        changeBlocker(id, "form", data.id, false);
        break;
      case "session.execution.started":
        activityChanges.set(id, { status: "running" });
        break;
      case "session.execution.succeeded":
      case "session.execution.interrupted":
        activityChanges.set(id, {
          status: "idle", outcome: event.type === "session.execution.succeeded" ? "succeeded" : "interrupted",
        });
        break;
      case "session.execution.failed":
        activityChanges.set(id, { status: "idle", outcome: "failed" });
        break;
      default:
        return;
    }
    publish();
  }

  const unsubscribe = api.data.listen(receive);
  syncSelection();
  const poll = setInterval(syncSelection, ROUTE_POLL_INTERVAL_MS);
  return () => {
    disposed = true;
    generation += 1;
    clearTimeout(retryTimer);
    clearInterval(poll);
    unsubscribe();
    sessions.clear();
    deleted.clear();
    activityChanges.clear();
    blockers.clear();
    blockerChanges.clear();
  };
}
