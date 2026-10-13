import QtQuick
import Quickshell
import Quickshell.Io
import "AgentState.js" as AgentState
import "HerdrProtocol.js" as Protocol

Item {
    id: root

    property string pluginId: "herdrAgents"
    property var pluginService: null
    property var snapshot: AgentState.unavailable("Connecting to Herdr…")
    property var latestAgents: []
    property string socketPath: ""
    property string transportMode: "connecting"
    property var requestConnection: null
    property var eventConnection: null
    property string subscribedRoster: ""
    property bool eventsAcknowledged: false
    property bool eventsSynchronized: false
    property bool subscriptionsUnavailable: false
    property bool refreshDirty: false
    property bool stopped: false
    property int eventRevision: 0
    property int subscriptionEpoch: 0
    property int nextRequestId: 0
    property int reconnectAttempt: 0
    property bool cliPending: false
    property bool cliTimedOut: false
    property string cliPurpose: ""
    property int snapshotRequests: 0
    property int cliRequests: 0

    // Public timing properties also let isolated integration tests use shorter
    // deadlines without changing production defaults or touching the live shell.
    property int requestTimeoutMs: 5000
    property int debounceMs: 50
    property int safetyIntervalMs: 60000
    property int fallbackIntervalMs: 10000
    property real reconnectTimeScale: 1

    function publish(nextSnapshot) {
        if (stopped || JSON.stringify(nextSnapshot) === JSON.stringify(snapshot))
            return;
        snapshot = nextSnapshot;
        if (pluginService)
            pluginService.setGlobalVar(pluginId, "snapshot", nextSnapshot);
    }

    function retire(connection) {
        if (!connection)
            return;
        connection.active = false;
        connection.connected = false;
        connection.destroy();
    }

    function closeConnections() {
        const request = requestConnection;
        const events = eventConnection;
        requestConnection = null;
        eventConnection = null;
        eventsAcknowledged = false;
        eventsSynchronized = false;
        requestDeadline.stop();
        subscriptionDeadline.stop();
        retire(request);
        retire(events);
    }

    function scheduleReconnect() {
        if (stopped || reconnectTimer.running)
            return;
        reconnectTimer.interval = Math.max(1, Protocol.reconnectDelay(reconnectAttempt) * reconnectTimeScale);
        reconnectAttempt = Math.min(reconnectAttempt + 1, 5);
        reconnectTimer.start();
    }

    function connectionFailed(message) {
        if (stopped)
            return;
        closeConnections();
        refreshDelay.stop();
        refreshDirty = false;
        latestAgents = [];
        socketPath = "";
        transportMode = "fallback";
        publish(AgentState.unavailable(message));
        scheduleReconnect();
    }

    function discoverAndConnect() {
        if (stopped)
            return;
        if (cliPending || requestConnection) {
            scheduleReconnect();
            return;
        }
        closeConnections();
        subscriptionsUnavailable = false;
        const overridePath = Quickshell.env("HERDR_SOCKET_PATH");
        if (overridePath) {
            socketPath = overridePath;
            refresh();
            return;
        }
        socketPath = "";
        runCli("discover");
    }

    function queueRefresh() {
        if (stopped)
            return;
        refreshDirty = true;
        // Do not restart this timer on each event: a continuous burst must not
        // postpone refresh forever. In-flight requests get one follow-up.
        if (!requestConnection && !cliPending && !refreshDelay.running)
            refreshDelay.start();
    }

    function refresh() {
        if (stopped)
            return;
        if (requestConnection || cliPending) {
            refreshDirty = true;
            return;
        }
        refreshDirty = false;
        if (!socketPath) {
            runCli("list");
            return;
        }
        const id = "herdr-agents:list:" + (++nextRequestId);
        requestConnection = socketComponent.createObject(root, {
            path: socketPath,
            requestId: id,
            requestFrame: Protocol.frameRequest(id, "agent.list", {}),
            eventVersion: eventRevision,
            syncEpoch: eventsAcknowledged ? subscriptionEpoch : -1
        });
        snapshotRequests++;
        requestDeadline.restart();
        requestConnection.connected = true;
    }

    function subscribe() {
        const previous = eventConnection;
        eventConnection = null;
        retire(previous);
        eventsAcknowledged = false;
        eventsSynchronized = false;
        subscribedRoster = Protocol.rosterKey(latestAgents);
        transportMode = "synchronizing";
        const id = "herdr-agents:subscribe:" + (++nextRequestId);
        let frame;
        try {
            frame = Protocol.frameRequest(id, "events.subscribe", {
                subscriptions: Protocol.subscriptions(latestAgents)
            });
        } catch (error) {
            usePollingFallback();
            return;
        }
        eventConnection = socketComponent.createObject(root, {
            path: socketPath,
            requestId: id,
            requestFrame: frame
        });
        subscriptionDeadline.restart();
        eventConnection.connected = true;
    }

    function usePollingFallback() {
        const previous = eventConnection;
        eventConnection = null;
        retire(previous);
        subscriptionDeadline.stop();
        eventsAcknowledged = false;
        eventsSynchronized = false;
        subscriptionsUnavailable = true;
        transportMode = "fallback";
        scheduleReconnect();
    }

    function receive(connection, line) {
        if (stopped || !connection.active
                || (connection !== requestConnection && connection !== eventConnection))
            return;
        let message;
        try {
            message = Protocol.parseLine(line);
        } catch (error) {
            connectionFailed(error.message);
            return;
        }
        if (!message)
            return;
        if (connection === eventConnection && message.event) {
            if (Protocol.isRelevantEvent(message)) {
                eventRevision++;
                queueRefresh();
            }
            return;
        }
        if (message.id !== connection.requestId)
            return;
        if (message.error) {
            if (connection === eventConnection) {
                usePollingFallback();
                return;
            }
            connectionFailed(message.error.message || "Herdr rejected the agent-list request.");
            return;
        }
        if (connection === eventConnection) {
            if (message.result.type !== "subscription_started") {
                connectionFailed("Herdr returned an unexpected subscription acknowledgement.");
                return;
            }
            subscriptionDeadline.stop();
            eventsAcknowledged = true;
            subscriptionEpoch++;
            queueRefresh();
            return;
        }

        requestConnection = null;
        requestDeadline.stop();
        retire(connection);
        let nextSnapshot;
        try {
            nextSnapshot = AgentState.snapshotFromResponse(JSON.stringify(message));
        } catch (error) {
            connectionFailed(error.message);
            return;
        }
        if (connection.eventVersion !== eventRevision) {
            queueRefresh();
            return;
        }
        latestAgents = nextSnapshot.agents;
        publish(nextSnapshot);
        if (!subscriptionsUnavailable && (!eventConnection || Protocol.rosterKey(latestAgents) !== subscribedRoster)) {
            subscribe();
        } else if (eventsAcknowledged && connection.syncEpoch === subscriptionEpoch) {
            eventsSynchronized = true;
            transportMode = "events";
            reconnectAttempt = 0;
            reconnectTimer.stop();
        }
        if (refreshDirty)
            queueRefresh();
    }

    function socketFailed(connection) {
        if (!stopped && connection.active
                && (connection === eventConnection || connection === requestConnection))
            connectionFailed("Herdr socket disconnected. Reconnecting…");
    }

    function readStream(connection, text) {
        if (stopped || !connection.active
                || (connection !== requestConnection && connection !== eventConnection))
            return;
        let frames;
        try {
            frames = Protocol.takeLines(text, connection.streamOffset);
        } catch (error) {
            connectionFailed(error.message);
            return;
        }
        connection.streamOffset = frames.offset;
        for (const line of frames.lines) {
            if (!connection.active)
                return;
            receive(connection, line);
        }
        // StdioCollector retains cumulative bytes. Renew busy subscriptions
        // before their buffer fills, then snapshot again to cover the handover.
        if (connection === eventConnection && eventsAcknowledged
                && frames.offset >= Protocol.rotateStreamCharacters)
            subscribe();
    }

    function runCli(purpose) {
        if (stopped || cliPending || requestConnection)
            return;
        cliPurpose = purpose;
        cliPending = true;
        cliTimedOut = false;
        cliRequests++;
        cli.command = purpose === "discover" ? ["herdr", "status", "--json"] : ["herdr", "agent", "list"];
        cliDeadline.restart();
        cli.running = true;
    }

    Component.onCompleted: {
        // Plugin globals can survive a hot reload. Clear the previous daemon's
        // snapshot immediately, even though this instance has the same default.
        if (pluginService)
            pluginService.setGlobalVar(pluginId, "snapshot", snapshot);
        discoverAndConnect();
    }

    Component.onDestruction: {
        stopped = true;
        reconnectTimer.stop();
        refreshDelay.stop();
        safetyTimer.stop();
        fallbackTimer.stop();
        cliDeadline.stop();
        closeConnections();
        if (cli.running)
            cli.signal(9);
    }

    Component {
        id: socketComponent
        Socket {
            id: channel
            property bool active: true
            property string requestId: ""
            property string requestFrame: ""
            property int eventVersion: -1
            property int syncEpoch: -1
            property int streamOffset: 0

            // The native collector re-decodes cumulative UTF-8 bytes, so even
            // splits inside a character are safe. Only complete lines advance
            // the offset; both complete and unfinished input are size-limited.
            parser: StdioCollector {
                waitForEnd: false
                onDataChanged: root.readStream(channel, text)
            }
            onConnectionStateChanged: {
                if (!active || root.stopped)
                    return;
                if (connected) {
                    write(requestFrame);
                    flush();
                } else {
                    root.socketFailed(channel);
                }
            }
            onError: root.socketFailed(channel)
        }
    }

    Timer {
        id: refreshDelay
        interval: root.debounceMs
        onTriggered: root.refresh()
    }
    Timer {
        id: requestDeadline
        interval: root.requestTimeoutMs
        onTriggered: root.connectionFailed("Herdr agent-list request timed out. Reconnecting…")
    }
    Timer {
        id: subscriptionDeadline
        interval: root.requestTimeoutMs
        onTriggered: root.connectionFailed("Herdr subscription handshake timed out. Reconnecting…")
    }
    Timer {
        id: reconnectTimer
        onTriggered: root.discoverAndConnect()
    }
    Timer {
        id: safetyTimer
        interval: root.safetyIntervalMs
        repeat: true
        running: root.eventsSynchronized && !root.stopped
        onTriggered: root.queueRefresh()
    }
    Timer {
        id: fallbackTimer
        interval: root.fallbackIntervalMs
        repeat: true
        running: !root.eventsSynchronized && !root.stopped
        onTriggered: root.queueRefresh()
    }
    Timer {
        id: cliDeadline
        interval: root.requestTimeoutMs
        onTriggered: {
            root.cliTimedOut = true;
            root.connectionFailed("Herdr CLI did not respond. Check that herdr is installed and its server is running.");
            if (cli.running)
                cli.signal(9);
            else
                root.cliPending = false;
        }
    }

    Process {
        id: cli
        stdout: StdioCollector { id: responseOutput }
        stderr: StdioCollector { id: errorOutput }

        onExited: (exitCode, exitStatus) => {
            cliDeadline.stop();
            root.cliPending = false;
            if (root.stopped || root.cliTimedOut)
                return;
            if (exitCode !== 0 || exitStatus !== 0) {
                const detail = errorOutput.text.trim().slice(0, 500);
                root.connectionFailed(detail || "Cannot reach Herdr. Check that its server is running.");
                return;
            }
            try {
                if (root.cliPurpose === "discover") {
                    root.socketPath = Protocol.socketPathFromStatus(responseOutput.text);
                    root.refresh();
                } else {
                    const nextSnapshot = AgentState.snapshotFromResponse(responseOutput.text);
                    root.latestAgents = nextSnapshot.agents;
                    root.publish(nextSnapshot);
                    root.transportMode = "fallback";
                    root.scheduleReconnect();
                    if (root.refreshDirty)
                        root.queueRefresh();
                }
            } catch (error) {
                root.connectionFailed(error.message);
            }
        }
    }

    IpcHandler {
        target: "herdr-agents"
        function status(): string {
            return JSON.stringify(root.snapshot);
        }
        function connection(): string {
            return JSON.stringify({
                mode: root.transportMode,
                socket: root.socketPath,
                synchronized: root.eventsSynchronized,
                reconnectAttempt: root.reconnectAttempt,
                requestPending: !!root.requestConnection || root.cliPending,
                subscribedPaneIds: Protocol.paneIds(root.latestAgents),
                snapshotRequests: root.snapshotRequests,
                cliRequests: root.cliRequests
            });
        }
    }
}
