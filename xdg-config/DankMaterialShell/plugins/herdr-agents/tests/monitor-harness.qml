import QtQuick
import Quickshell
import "." as Plugin

Item {
    id: root
    property var monitor: null
    property var expected: JSON.parse(Quickshell.env("HERDR_TEST_EXPECTED") || "[]")
    property int received: 0
    property string lastState: ""
    property bool cleanupComplete: false

    function finish() {
        console.log("HERDR_DIAGNOSTICS:" + JSON.stringify({
            mode: monitor?.transportMode,
            synchronized: monitor?.eventsSynchronized,
            snapshotRequests: monitor?.snapshotRequests,
            cliRequests: monitor?.cliRequests,
            finalSnapshot: monitor?.snapshot,
            initialCleared: fakeService.initialCleared,
            cleanupComplete: cleanupComplete
        }));
        Qt.quit();
    }

    Item {
        id: fakeService
        property bool initialCleared: false
        function setGlobalVar(pluginId, name, snapshot) {
            if (snapshot.error === "Connecting to Herdr…") {
                initialCleared = true;
                return;
            }
            const state = snapshot.available ? snapshot.state : "unavailable";
            if (state === root.lastState)
                return;
            root.lastState = state;
            console.log("HERDR_SNAPSHOT:" + JSON.stringify({ time: Date.now(), snapshot: snapshot }));
            if (state !== root.expected[root.received]) {
                console.error("Unexpected state: " + state);
                Qt.quit();
                return;
            }
            root.received++;
        }
    }

    Component {
        id: monitorComponent
        Plugin.HerdrMonitor {}
    }

    Component.onCompleted: {
        monitor = monitorComponent.createObject(root, {
            pluginService: fakeService,
            requestTimeoutMs: Quickshell.env("HERDR_TEST_MODE") === "cleanup-cli" ? 5000 : 500,
            debounceMs: 50,
            safetyIntervalMs: Number(Quickshell.env("HERDR_TEST_SAFETY_MS") || 10000),
            fallbackIntervalMs: 200,
            reconnectTimeScale: 0.05
        });
        if (Quickshell.env("HERDR_TEST_MODE").startsWith("cleanup"))
            destroyTimer.start();
    }

    Timer {
        id: destroyTimer
        interval: 750
        onTriggered: {
            root.monitor.destroy();
            root.monitor = null;
            root.cleanupComplete = true;
            exitTimer.start();
        }
    }

    Timer {
        id: exitTimer
        interval: 250
        onTriggered: root.finish()
    }

    Timer {
        interval: 20
        repeat: true
        running: true
        onTriggered: {
            if (!root.monitor || root.received !== root.expected.length)
                return;
            const mode = Quickshell.env("HERDR_TEST_MODE");
            if (mode.startsWith("cleanup"))
                return;
            const allowFallback = (mode === "unsupported" || mode === "cli-fallback" || mode === "missing")
                && root.monitor.transportMode === "fallback";
            if (root.monitor.eventsSynchronized || allowFallback)
                root.finish();
        }
    }

    Timer {
        interval: 12000
        running: true
        onTriggered: {
            console.error("Monitor harness timed out");
            Qt.quit();
        }
    }
}
