var states = ["blocked", "done", "working", "idle", "unknown"];

function displayString(value) {
    return typeof value === "string" ? value.replace(/[\r\n\t]+/g, " ").trim() : "";
}

function normalizeAgent(agent) {
    if (!agent || typeof agent !== "object" || Array.isArray(agent))
        throw new Error("Herdr returned an invalid agent entry.");

    var paneId = displayString(agent.pane_id);
    if (!paneId)
        throw new Error("Herdr returned an agent without a pane ID.");

    var state = states.indexOf(agent.agent_status) !== -1 ? agent.agent_status : "unknown";
    var kind = displayString(agent.agent) || "Unknown agent";
    var directory = displayString(agent.foreground_cwd) || displayString(agent.cwd);
    var title = displayString(agent.terminal_title_stripped) || displayString(agent.terminal_title);

    return {
        paneId: paneId,
        state: state,
        kind: kind,
        directory: directory,
        title: title || directory.split("/").filter(Boolean).pop() || kind
    };
}

function parseResponse(text) {
    var response;
    try {
        response = JSON.parse(text);
    } catch (error) {
        throw new Error("Herdr returned invalid JSON.");
    }

    if (!response || !response.result || response.result.type !== "agent_list"
            || !Array.isArray(response.result.agents))
        throw new Error("Herdr returned an unexpected agent-list response.");

    return response.result.agents.map(normalizeAgent).sort(function (left, right) {
        var priority = states.indexOf(left.state) - states.indexOf(right.state);
        if (priority !== 0)
            return priority;
        return left.paneId.localeCompare(right.paneId);
    });
}

function aggregateState(agents) {
    if (agents.length === 0)
        return "empty";

    for (var i = 0; i < 3; i++) {
        if (agents.some(function (agent) { return agent.state === states[i]; }))
            return states[i];
    }

    return agents.every(function (agent) { return agent.state === "idle"; }) ? "idle" : "unknown";
}

function snapshotFromResponse(text) {
    var agents = parseResponse(text);
    var state = aggregateState(agents);
    return {
        agents: agents,
        state: state,
        filled: state === "blocked" || state === "done" || state === "working",
        visible: agents.length > 0,
        available: true,
        error: ""
    };
}

function unavailable(message) {
    return {
        agents: [],
        state: "unknown",
        filled: false,
        visible: true,
        available: false,
        error: message
    };
}

function stateLabel(state) {
    return state.charAt(0).toUpperCase() + state.slice(1);
}

function summary(snapshot) {
    if (!snapshot.available)
        return snapshot.error;
    if (snapshot.agents.length === 0)
        return "No agents in the local Herdr session";

    return states.map(function (state) {
        var count = snapshot.agents.filter(function (agent) { return agent.state === state; }).length;
        return count ? count + " " + state : "";
    }).filter(Boolean).join(" · ");
}
