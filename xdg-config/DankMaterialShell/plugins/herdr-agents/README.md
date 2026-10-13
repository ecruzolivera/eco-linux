# Herdr Agents

A single robot icon in DankBar for the agents in the default local Herdr session.
Requires DMS 1.6+, Quickshell with Qt 6.7+ and `QtQuick.Shapes`, and a running
local Herdr server with `herdr` on the shell's PATH. No eco-linux configuration
or OpenCode-specific patch is required to install the widget.

The Pictogrammers `robot` and `robot-outline` shapes are rendered as native QML
vectors with `QtQuick.Shapes`' curve renderer, without SVG textures or masks.
Both variants have eyes 25% smaller than the originals; eye centers and the rest
of each robot are unchanged. Original SVGs in `icons/` are regression fixtures,
not runtime images; see `icons/README.md` for attribution and licensing.

## Compatibility and scope

Tested on Arch Linux with DMS 1.6.0, Quickshell 0.3.1, Qt 6.11.2, and Herdr
0.9.3 (protocol 22). Other versions and distributions are not yet verified.
The requested curve renderer provides antialiased edges on Qt Quick's normal
graphics backend; Qt selects its software renderer when using that backend.

The widget displays Herdr's reported states for any agent type. It does not
detect activity itself or fix errors in an agent integration. The separately
maintained OpenCode integration fix is not bundled or automatically installed.

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

Install only this plugin directory, not anyone else's DMS settings or dotfiles.
For a downloaded/extracted copy, from its root:

```sh
destination="${XDG_CONFIG_HOME:-$HOME/.config}/DankMaterialShell/plugins/herdr-agents"
# Refuse to overwrite an existing installation, including a dangling symlink.
if [ -e "$destination" ] || [ -L "$destination" ]; then
    echo "Already exists: $destination; back it up before installing."
else
    mkdir -p "$(dirname "$destination")"
    cp -a . "$destination"
fi
```

Once a public Git URL is available, clone it directly into that destination
instead; never run `git clone` over an existing plugin directory.
Then enable via Settings → Plugins → Scan for Plugins, or:

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

To remove the plugin, first disable it in Settings → Plugins and remove its
DankBar entry. Then remove only its installation directory if no longer needed.

## Troubleshooting and privacy

- **Gray icon:** click for the error. Check `herdr status --json` from the same
  desktop environment; DMS must inherit a PATH containing `herdr`.
- **Alternate socket:** export `HERDR_SOCKET_PATH` before launching DMS.
  Setting it only in a terminal does not change an already-running shell.
- **Wrong agent status:** inspect Herdr's own agent list. This widget does not
  reinterpret a failed child or acknowledge completion on a click.
- **Invisible icon:** no agents intentionally means no icon or reserved space.
- **Updates:** back up local edits first, update the installed files, then reload.

No telemetry, external web requests, or desktop notifications are made by this
plugin. Click details and diagnostic output contain local titles, directories,
and pane IDs; review them before sharing screenshots or logs. DMS plugins run
with your desktop session permissions, not in a security sandbox.

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
dependencies. From this repository's root, run unit tests with Node 20+:

```sh
node --test tests/agent-state.test.cjs tests/herdr-protocol.test.cjs
```

Run the full suite with Quickshell installed:

```sh
node --test tests/*.test.cjs
```

Integration tests find `qs` or `quickshell` on PATH, or accept an absolute
executable path through `HERDR_TEST_QS`. Their fake CLI uses the same Node binary
as the test runner. Tests use `TMPDIR` when set, otherwise `/tmp/opencode/` if
present or the OS temporary directory. They run isolated, non-visual QML
monitors against a fake Unix-socket server and CLI, never your real Herdr.
Use a short temporary path: Unix-socket names have a platform length limit,
and the tests fail clearly if the generated endpoint would exceed it.
The suite verifies sub-250ms event updates, fragmentation, UTF-8, bursts,
roster changes, bounded buffers, stale replies, server/endpoint restarts,
timeouts, fallback, safety refreshes, and cleanup without touching your real
Herdr session.
Named sessions, remote machines, and click-to-focus are intentionally not included.

## License

Plugin code and documentation: MIT, see `LICENSE`.
Pictogrammers artwork, including the adapted QML paths: Apache-2.0,
see `icons/README.md`, `icons/UPSTREAM-LICENSE`, and `icons/LICENSE-APACHE-2.0`.
