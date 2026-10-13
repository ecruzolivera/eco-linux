var maxFrameCharacters = 1024 * 1024;
var rotateStreamCharacters = maxFrameCharacters / 2;
var lifecycleSubscriptions = [
    "pane.created", "pane.closed", "pane.updated", "pane.exited",
    "pane.moved", "pane.agent_detected", "tab.closed", "workspace.closed"
];

function takeLines(text, offset) {
    if (text.length > maxFrameCharacters)
        throw new Error("Herdr socket input buffer exceeded its limit.");
    var lastNewline = text.lastIndexOf("\n");
    if (lastNewline < offset)
        return { lines: [], offset: offset };
    return { lines: text.slice(offset, lastNewline).split("\n"), offset: lastNewline + 1 };
}

function parseLine(line) {
    if (line.length > maxFrameCharacters)
        throw new Error("Herdr returned a JSON frame larger than one MiB.");
    if (!line.trim())
        return null;
    var message;
    try {
        message = JSON.parse(line);
    } catch (error) {
        throw new Error("Herdr returned invalid socket JSON.");
    }
    if (!message || typeof message !== "object" || Array.isArray(message))
        throw new Error("Herdr returned an invalid socket envelope.");
    if (typeof message.id === "string" && (message.result || message.error))
        return message;
    if (typeof message.event === "string" && message.data && typeof message.data === "object")
        return message;
    throw new Error("Herdr returned an unexpected socket envelope.");
}

function frameRequest(id, method, params) {
    if (method !== "agent.list" && method !== "events.subscribe")
        throw new Error("Unsupported Herdr monitor request: " + method);
    var frame = JSON.stringify({ id: id, method: method, params: params });
    if (frame.length > maxFrameCharacters)
        throw new Error("Herdr monitor request is too large.");
    return frame + "\n";
}

function paneIds(agents) {
    return agents.map(function (agent) { return agent.paneId; }).sort().filter(function (id, index, ids) {
        return index === 0 || id !== ids[index - 1];
    });
}

function rosterKey(agents) {
    return JSON.stringify(paneIds(agents));
}

function subscriptions(agents) {
    return lifecycleSubscriptions.map(function (type) { return { type: type }; }).concat(
        paneIds(agents).map(function (paneId) {
            return { type: "pane.agent_status_changed", pane_id: paneId };
        })
    );
}

function isRelevantEvent(message) {
    if (typeof message.event !== "string")
        return false;
    // Herdr has both dotted subscription envelopes and snake_case lifecycle
    // envelopes; agent_detected/status_changed contain an underscore themselves.
    var canonical = message.event.replace(/\./g, "_");
    return canonical === "pane_agent_status_changed"
        || lifecycleSubscriptions.some(function (type) { return type.replace(/\./g, "_") === canonical; });
}

function socketPathFromStatus(text) {
    var status;
    try {
        status = JSON.parse(text);
    } catch (error) {
        throw new Error("Herdr returned invalid status JSON.");
    }
    var path = status && status.server && status.server.socket;
    if (typeof path !== "string" || !path.trim())
        throw new Error("Herdr has no local socket. Check that its server is running.");
    return path;
}

function reconnectDelay(attempt) {
    return Math.min(30000, 1000 * Math.pow(2, Math.min(attempt, 5)));
}
