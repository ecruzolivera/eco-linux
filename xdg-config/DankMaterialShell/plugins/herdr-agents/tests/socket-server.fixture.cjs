// Isolated test server. Never connects to Herdr or touches the user's settings.
const fs = require("node:fs");
const net = require("node:net");
const path = require("node:path");

const directory = process.env.HERDR_TEST_DIRECTORY;
const mode = process.env.HERDR_TEST_MODE;
const endpointFile = path.join(directory, "endpoint");
const logFile = path.join(directory, "server-events");
const statsFile = path.join(directory, "server-stats.json");
let endpoint = path.join(directory, "herdr.sock");
let server;
let agents = mode === "empty" || mode === "new-agent" ? [] : [agent("p1", initialState())];
let scheduled = false;
let firstFaultUsed = false;
let activeRequests = 0;
const clients = new Set();
const subscribers = new Set();
const stats = { lists: 0, subscriptions: [], maxConcurrentRequests: 0, openConnections: 0, triggers: [] };

function initialState() {
    return ["event", "burst", "race", "roster", "reconnect", "relocate", "safety", "slow", "stream-rotation", "event-partial"].includes(mode) ? "idle" : "blocked";
}

function agent(pane, state) {
    return { pane_id: pane, agent: "opencode", agent_status: state,
        cwd: "/test/project", terminal_title_stripped: "Traducción 🐑 — sesión" };
}

function persist() {
    stats.openConnections = clients.size;
    fs.writeFileSync(statsFile, JSON.stringify(stats));
}

function trigger(event, data = {}) {
    const time = Date.now();
    stats.triggers.push({ time, event });
    fs.appendFileSync(logFile, JSON.stringify({ time, event }) + "\n");
    const line = JSON.stringify({ event, data }) + "\n";
    for (const socket of subscribers) socket.write(line);
    persist();
}

function scheduleScenario() {
    if (scheduled || stats.lists < 2 || subscribers.size === 0)
        return;
    scheduled = true;
    setTimeout(() => {
        switch (mode) {
        case "event":
        case "burst":
        case "slow":
            agents = [agent("p1", "done")];
            for (let i = 0; i < (mode === "burst" || mode === "slow" ? 100 : 1); i++)
                trigger("pane.agent_status_changed", { pane_id: "p1", agent_status: "done" });
            break;
        case "race":
            agents = [agent("p1", "working")];
            trigger("pane_agent_status_changed", { pane_id: "p1", agent_status: "working" });
            break;
        case "stream-rotation":
            agents = [agent("p1", "done")];
            for (let i = 0; i < 8; i++)
                trigger("pane_updated", { pane: agents[0], padding: "x".repeat(80000) });
            break;
        case "event-partial":
            agents = [agent("p1", "done")];
            for (const socket of subscribers) socket.write("x".repeat(1024 * 1024 + 1));
            break;
        case "roster":
            agents.push(agent("p2", "done"));
            trigger("pane_created", { pane: agents[1] });
            break;
        case "removal":
            agents = [];
            trigger("tab_closed", { tab_id: "t1", workspace_id: "w1" });
            break;
        case "new-agent":
            agents = [agent("p1", "done")];
            trigger("pane_agent_detected", { pane_id: "p1", agent: "opencode" });
            break;
        case "reconnect":
        case "relocate":
            for (const socket of clients) socket.destroy();
            server.close(() => {
                if (fs.existsSync(endpoint)) fs.unlinkSync(endpoint);
                if (mode === "relocate") endpoint = path.join(directory, "new-herdr.sock");
                agents = [agent("p1", "done")];
                setTimeout(startServer, 100);
            });
            break;
        case "safety":
            agents = [agent("p1", "done")];
            persist();
            break;
        }
    }, 100);
}

function answerList(socket, request) {
    stats.lists++;
    activeRequests++;
    stats.maxConcurrentRequests = Math.max(stats.maxConcurrentRequests, activeRequests);
    const captured = JSON.parse(JSON.stringify(agents));
    const count = stats.lists;
    let completed = false;
    function finish() {
        if (completed) return;
        completed = true;
        activeRequests--;
        persist();
    }
    socket.once("close", finish);
    const reply = JSON.stringify({ id: request.id, result: { type: "agent_list", agents: captured } }) + "\n";
    if (!firstFaultUsed && ["invalid", "timeout", "partial", "oversized"].includes(mode)) {
        firstFaultUsed = true;
        if (mode === "invalid") socket.end("not json\n");
        else if (mode === "partial") socket.write(reply.slice(0, 30));
        else if (mode === "oversized") socket.end("x".repeat(1024 * 1024 + 1) + "\n");
        persist();
        return;
    }
    const send = () => {
        if (socket.destroyed) return;
        if (mode === "wrong-id") {
            socket.write(JSON.stringify({ id: "unrelated", result: { type: "agent_list", agents: [] } }) + "\n");
            socket.end(reply);
        } else if (mode === "utf8") {
            const bytes = Buffer.from(reply);
            const split = bytes.indexOf(Buffer.from("ó")) + 1;
            socket.write(bytes.subarray(0, split));
            setTimeout(() => { if (!socket.destroyed) socket.end(bytes.subarray(split)); }, 10);
        } else socket.end(reply);
        finish();
        scheduleScenario();
    };
    if (mode === "race" && count === 3) {
        setTimeout(() => {
            agents = [agent("p1", "done")];
            trigger("pane.agent_status_changed", { pane_id: "p1", agent_status: "done" });
        }, 30);
        setTimeout(send, 100);
    } else if (mode === "slow" && count === 3) {
        setTimeout(() => trigger("pane_updated", { pane: agents[0] }), 50);
        setTimeout(send, 300);
    } else send();
    persist();
}

function startServer() {
    fs.writeFileSync(endpointFile, endpoint);
    server = net.createServer(socket => {
        clients.add(socket);
        persist();
        socket.on("error", () => {});
        socket.on("close", () => {
            clients.delete(socket);
            subscribers.delete(socket);
            persist();
        });
        let buffer = "";
        socket.on("data", chunk => {
            buffer += chunk.toString();
            let index;
            while ((index = buffer.indexOf("\n")) !== -1) {
                const request = JSON.parse(buffer.slice(0, index));
                buffer = buffer.slice(index + 1);
                if (subscribers.has(socket)) {
                    // Like the real server, a subscribed channel is not a request channel.
                    socket.destroy();
                    continue;
                }
                if (request.method === "agent.list") answerList(socket, request);
                else if (request.method === "events.subscribe") {
                    stats.subscriptions.push(request.params.subscriptions);
                    persist();
                    if (mode === "unsupported") {
                        socket.end(JSON.stringify({ id: request.id, error: { code: "unsupported", message: "Subscriptions unsupported" } }) + "\n");
                    } else if (mode === "handshake" && !firstFaultUsed) {
                        firstFaultUsed = true;
                    } else {
                        subscribers.add(socket);
                        const ack = JSON.stringify({ id: request.id, result: { type: "subscription_started" } }) + "\n";
                        // Split the ack as well to exercise native NDJSON framing.
                        socket.write(ack.slice(0, 5));
                        setTimeout(() => { if (!socket.destroyed) socket.write(ack.slice(5)); }, 5);
                    }
                } else socket.destroy();
            }
        });
    });
    server.listen(endpoint, () => {
        persist();
        if (process.send) process.send({ ready: true });
    });
}

startServer();
