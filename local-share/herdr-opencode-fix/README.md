# Herdr OpenCode V2 reliability patch

Local patch for Herdr 0.9.3, integration v13, tested with OpenCode 2.0.26.
Upstream: <https://github.com/herdrdev/herdr/tree/v0.9.3/src/integration/assets/opencode>.

## Installed change

Only `~/.config/opencode/herdr-tui-session.js` is replaced. Existing CLI plugin
registration, V2 entrypoint, server plugin, V1 lifecycle implementation, project
configuration, and credentials are unchanged.

- Reconcile asynchronously hydrated activity on the existing 100 ms route poll.
- Aggregate the selected root and its descendants: pending requests or a failure
  of the selected root are `blocked`; otherwise any running member is `working`;
  otherwise the pane is `idle`. A failed subagent never blocks its parent by
  itself, even during the same execution; its error remains in OpenCode history.
- Send an `idle` settlement when leaving a session for home, including retrying
  failed deliveries. Selection generations prevent stale queued reports from
  being attributed to a newly selected session.
- Preserve newer lifecycle and blocker deltas until cache acknowledgement.
  Reconnection releases descendant activity deltas for fresh hydration while
  retaining an actionable root failure. Parent retries cannot revive a failed
  child's stale running snapshot.
- Keep bounded socket timeouts, delivery retries, deletion handling, pane-local
  ownership, and cleanup. Outside Herdr the plugin does nothing.

Restart the OpenCode TUI in each Herdr pane to load the updated file. No running
terminal was restarted during deployment. Mini/headless reporting remains
unsupported by this upstream integration.

## Files

- `upstream/`: unmodified official integration and upstream test baseline.
- `source/`: patched implementation, regression tests, and real-socket workers.
- `herdr-v13-v2-reliability.patch`: patch against the upstream repository paths;
  checked to apply cleanly and reproduce the tested files exactly.
- `metadata.json`: version provenance, checksums, backup location, and results.
- `deploy.mjs`: checksum-guarded, atomic deployment and rollback with backups.

## Verify

Run the suites separately because the upstream suites mock sockets:

```sh
cd ~/.local/share/herdr-opencode-fix/source
bun test ./herdr-tui-session.test.ts
bun test ./herdr-agent-state.test.ts
bun test ./herdr-v2-socket.test.ts
bun test ./herdr-deploy.test.ts
```

Recorded result: **65 passing tests** (48 terminal, 9 server, 3 real-socket,
5 deployment).
The socket tests use isolated local fixtures and two independent Node processes;
they do not control a real Herdr session. All three original regressions were
also verified through the actual deployed V2 entrypoint using mocked APIs.
Deployment, idempotence, permission preservation, rollback, and refusal to
overwrite unfamiliar edits were rehearsed in isolated sandboxes.

## Reapply or roll back

```sh
node ~/.local/share/herdr-opencode-fix/deploy.mjs --check
node ~/.local/share/herdr-opencode-fix/deploy.mjs --apply
```

Herdr reinstalls/updates overwrite its generated integration files. The deployer
accepts only the recorded upstream v13 file, verified patch, or recorded earlier
patches. If a new Herdr version or another edit changes the file, it refuses to
overwrite it: review/rebase against that upstream version and rerun tests before
updating checksums. Reapplication is manual; no update hooks were installed.

To restore the recorded official v13 terminal plugin:

```sh
node ~/.local/share/herdr-opencode-fix/deploy.mjs --rollback
```

Restart the affected OpenCode TUIs after applying or rolling back. Each actual
replacement creates a backup under `~/.config/opencode-migration-backups/`.

`--rollback` restores official upstream v13, not the previous reliability patch.
To undo just this update, restore the exact pre-update file from its deployment
backup only after verifying that backup against a recorded earlier checksum and
the installed file against the current checksum; preserve mode and use an atomic
replacement. This restoration is covered by the isolated deployment tests.

For an upstream checkout of Herdr v0.9.3, run from that repository root:

```sh
git apply --check ~/.local/share/herdr-opencode-fix/herdr-v13-v2-reliability.patch
git apply ~/.local/share/herdr-opencode-fix/herdr-v13-v2-reliability.patch
```

## Outstanding live validation

This session is outside Herdr (`HERDR_ENV`, `HERDR_PANE_ID`, and
`HERDR_SOCKET_PATH` were absent); Herdr was not running at the initial check.
No Herdr panes or sessions were controlled. Automated socket checks are not a
substitute for live UI validation.

From a real Herdr-managed session, verify after restarting its OpenCode TUI:

1. Open a session already executing; the pane becomes `working` after hydration.
2. Navigate home during execution or a permission/form prompt; the pane settles
   to `idle` and does not remain stuck after later completion.
3. Run background descendants; the root pane remains `working` until all finish,
   with permissions/forms taking precedence as `blocked`.
4. Retry failed execution, reconnect, rapidly switch roots, and delete sessions;
   confirm no stale activity is attributed to the newly selected root.
5. Repeat in two panes attached to distinct roots; one pane's child activity or
    blockers must not change the other pane's reporting.
6. Fail a subagent while its parent continues: the pane remains `working`, then
   becomes `idle` when all execution ends. A pending permission/form still shows
   `blocked`, as does a failure of the root itself. Child retries and reconnects
   must not revive old errors or strand the pane on a stale state.

These live checks remain pending; implementation and deployment are complete.
