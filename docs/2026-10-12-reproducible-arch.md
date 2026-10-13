---
status: complete
phase: 4
updated: 2026-10-12
---

# Reproducible Arch setup — implementation record

## Goal

Implement phases 1–4 so eco-linux provisions the working niri/DMS desktop, development integrations and selected personal applications on bootable x86_64 Arch without Omarchy repositories.

## Context & Decisions

| Decision | Rationale | Source |
| --- | --- | --- |
| Track current Arch/AUR applications, pin only the integration pair | Recreate functionality rather than a frozen distro snapshot; patch compatibility is stricter | `ref:../packages/integrations.lock`, `ref:../local-share/herdr-opencode-fix/metadata.json` |
| Use interactive AUR review and normal sudo | Avoid a persistent root-escalation grant on failure/interruption | `ref:../lib/installer.sh`, `ref:../scripts/02-yay.sh` |
| Keep existing files; back up explicit replacements | Reruns must not silently discard the user's later changes | `ref:../lib/deploy-config.py` |
| Preserve original displays as an opt-in profile | Connectors/scales are not portable | `ref:../profiles/ernesto/xdg-config/`, `ref:../xdg-config/niri/monitors.kdl` |
| Leave boot integration and network migration to the base install | Avoid imposing Limine, Btrfs, or a particular resolver on arbitrary Arch; package hooks still apply | `ref:../scripts/09-docker.sh`, `ref:../packages/omissions.toml`, `ref:../README.md` |
| Verify Herdr install results, not only exit status | Declining a plugin install exits successfully in Herdr 0.9.3 | `ref:https://raw.githubusercontent.com/herdrdev/herdr/v0.9.3/src/cli/plugin.rs`, `ref:../lib/bootstrap-herdr.py` |

## Phase 1: Harden installation [COMPLETE]

- [x] 1.1 Resolve local checkout/module paths independently of caller cwd.
- [x] 1.2 Require an explicit standalone revision and use owned temporary directories.
- [x] 1.3 Validate Arch/architecture, account/home ownership, terminal, sudo and HTTPS before provisioning; refuse active Omarchy and legacy sudo grants.
- [x] 1.4 Upgrade coherently with `pacman -Syu`; no database-only refreshes.
- [x] 1.5 Eliminate passwordless pacman grants; scope yay/AUR build cwd and cleanup.
- [x] 1.6 Add inert/mocked failure, interruption, rerun and missing-yay tests. → `ref:../tests/verify-installer.py`

## Phase 2: Personal application profile [COMPLETE]

- [x] 2.1 Split core/personal Arch and AUR manifests; eliminate duplicates and the redundant `nvim` provider request.
- [x] 2.2 Account for all 314 source-machine explicit packages through selected manifests and documented omission categories. → `ref:../packages/omissions.toml`
- [x] 2.3 Validate Niri launcher/helper executable providers; include the missing PWA menu and avoid a duplicate authentication agent.
- [x] 2.4 Check official names against cached Arch databases and all 23 unpinned AUR names through RPC; use `xdg-terminal-exec-git`, not an unavailable same-name replacement.
- [x] 2.5 Capture the global new-repository `master` rule, retaining gdu and Temurin preferences.

## Phase 3: Hardware separation [COMPLETE]

- [x] 3.1 Retain display/workspace/DMS preferences under the optional `ernesto` profile; detect battery names rather than assuming BAT0.
- [x] 3.2 Preserve existing NVIDIA drivers; conservative modern-GPU selection and installed-kernel header checks, without global renderer forcing.
- [x] 3.3 Preserve network/resolver and existing Docker configuration; explicitly selected NetworkManager refuses competing managers.
- [x] 3.4 Exclude Limine/Snapper packages/configuration from the portable recipe; no disk/filesystem/snapshot manipulation.
- [x] 3.5 Make autologin explicit without editing PAM or weakening keyrings.

## Phase 4: User bootstrap [COMPLETE]

- [x] 4.1 Deploy/setup as the normal user; no recursive home ownership rewrite.
- [x] 4.2 Trust/install mise runtimes and validate Java 21 plus Node/npm/npx/Bun/Go; ensure Rust for the reviewed git-status plugin.
- [x] 4.3 Restore/verify enabled locked Neovim revisions and required Mason tools, then check LTeX+.
- [x] 4.4 Check the exact integration pair; register reviewed plugins and verify results, preserving unfamiliar/modified installations; use the unchanged guarded patch deployer.
- [x] 4.5 Report user-stage failures/optional skips and final package/command coverage; exclude authentication, model requests, personal data and licensed media.
- [x] 4.6 Complete final safe regression review and confirm live configuration/Git HEAD unchanged.

## Deferred validation (outside this implementation scope)

No clean-VM provisioning or physical suspend/GPU tests have run. Safe tests do not
prove fresh package builds, downloads, graphical login or real editor/plugin
bootstrap. Validate on disposable Arch with a different username, no yay/mise
tools and no Omarchy repositories; test complete installation, login, rerun and
interrupted stages. Resume stability must be tested on the actual hybrid GPU
hardware before any eventual Omarchy migration.

## Notes

- Existing repo changes remain intact; no live installer, commit or push is part of this work.
- Optional/specialized tools and external `tobi-try`/Wonderdraft installations require review; omission is not a removal request.
- Required failures stop progression; completed package/system changes are not rolled back automatically.
- The pinned AUR recipes can become incompatible with future Arch dependencies; failures are surfaced, not bypassed. This is not a coherent archived Arch snapshot.
- Safe verification passed: 16 installer tests, four mocked Neovim provisioning cases, configuration-copy/syntax checks, all 68 Herdr widget tests, cached official-package coverage and classification of all 314 installed explicit packages. AUR RPC confirmed all 23 unpinned names; pinned recipe commits were inspected separately.
- Final checks confirmed 21 live configuration fingerprints, Git HEAD/index and pre-existing custom plugin/gdu/mise/Herdr patch/project OpenCode payloads unchanged. Original monitor/workspace preferences remain in the optional profile (only a profile comment/final-newline adjustment).
