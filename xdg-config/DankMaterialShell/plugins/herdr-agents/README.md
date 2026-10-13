# Herdr Agents

A single `smart_toy` robot icon in DankBar for the agents in the default local Herdr session.
Requires DMS 1.6+ and `herdr` on the shell's PATH.

## States

Rules are evaluated from top to bottom:

| Condition | Appearance |
| --- | --- |
| Any blocked | Filled red |
| Otherwise, any done | Filled green |
| Otherwise, any working | Filled yellow |
| All idle | Outlined green |
| Remaining unknown combinations | Outlined gray |
| No agents | Hidden, with no reserved bar space |
| Herdr unavailable or invalid response | Outlined gray with error details |

Colors come from your active Dank16 red/green/yellow palette where available,
with semantic fallbacks. A done agent stays done until Herdr updates it; viewing
the details never clears or acknowledges an agent's state.

Click for the scrollable list of titles, agent types, states, pane IDs, and
directories. Hover never shows a tooltip or opens the details, even when
DankBar hover popouts are enabled.

## Event-driven monitoring

All bars share one daemon. It discovers the Unix socket from `HERDR_SOCKET_PATH`
when set, otherwise from `herdr status --json`, then reads an initial agent list.
A persistent socket subscribes to per-pane agent status changes and pane, tab,
and workspace lifecycle events. Separate, short-lived request sockets fetch
authoritative agent lists; Herdr does not accept ordinary requests on an event
connection and closes request connections after replying.

Events are coalesced over 50 milliseconds. Requests never overlap, and an event
received during a request causes its potentially stale reply to be discarded and
a fresh list requested. Roster changes rebuild the pane subscriptions; another
snapshot after the subscription acknowledgement covers the connection handover.
Event updates preserve icon priorities and never open the click-only details.

Healthy operation launches no CLI process per update. A safety snapshot every
60 seconds repairs missed events. Unsupported subscriptions fall back to socket
polling every 10 seconds; the CLI is a last resort when no socket is usable.
Failed connections or invalid data clear stale agents and show outlined gray.
Reconnect delays grow from 1 to 2, 4, 8, 16, then at most 30 seconds. Socket
discovery repeats on reconnect, and backoff resets only after resynchronization.

Connections, handshakes, requests, and CLI processes have five-second deadlines.
Cumulative socket input is limited to one million characters, including partial
frames. Busy subscription streams rotate at half that limit and resynchronize,
bounding retained data while preserving fragmented UTF-8. Disabling the plugin
closes sockets, stops timers, and terminates any fallback process. There are no
Herdr configuration changes, agent controls, or desktop notifications.

## Enable

Place this directory at `~/.config/DankMaterialShell/plugins/herdr-agents/`, then:

```sh
dms ipc call plugin-scan scan
dms ipc call plugins enable herdrAgents
```

In Settings → DankBar, add **Herdr Agents** to the desired bar section.
Existing widgets do not need to be removed. To reload after editing:

```sh
dms ipc call plugins reload herdrAgents
```

When an update adds new helper files, DMS/Quickshell may retain an old file list.
Use `dms restart` once if hot reload reports a missing file or case mismatch.
This restarts only the desktop shell, not Herdr or your agents.

## Diagnostics and tests

```sh
dms ipc call herdr-agents status
dms ipc call herdr-agents connection
node --test ~/.config/DankMaterialShell/plugins/herdr-agents/tests/*.test.cjs
```

The status command exposes the normalized snapshot used by the widget. The
connection command reports event/fallback mode, synchronization, endpoint,
subscribed pane IDs, and socket/CLI request counters.

Tests exercise the exact same JavaScript imported by QML, with no npm
dependencies. The integration suite requires Node and `/usr/bin/qs`, and runs
isolated, non-visual QML monitors against a fake Unix-socket server and CLI in
`/tmp/opencode/`. It verifies sub-250ms event updates, fragmentation, UTF-8, bursts,
roster changes, bounded buffers, stale replies, server/endpoint restarts,
timeouts, fallback, safety refreshes, and cleanup without touching your real
Herdr session.
Named sessions, remote machines, and click-to-focus are intentionally not included.
