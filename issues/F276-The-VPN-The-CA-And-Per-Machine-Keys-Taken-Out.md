# F276 — The VPN, The CA And Per-Machine Keys Taken Out

**Status:** Implementing. Estimated and Backlog (operator, 2026-10-30, sprint 6m).
**Size:** L - several days to remove flows across the app and host package, preserve old rental records safely, and retire their tests and walks.

**What must be true.** The interface no longer has: the WireGuard VPN and its root step (`host_vpn.dart`, `own_host_vpn.dart`, the tunnel files), the host CA and Firefox's policy, the `/etc/hosts` lines, the stops for the CA, the forge password, identities and the central forge's token, per-machine keys and *Copy my public keys for a host…* (`join_keys.dart`), the access file's laptops, the project's own signing key and `signed_by`, and the bring, join and Developers wizard steps that paste host values or keys. A record of a host kept from before is shown as "made before one-click joining: give it back or set it up again". Walks 17–23 are deleted.

## Why

One-click joining from signed state (operator, 2026-10-30): no VPN, no host CA, no forge password, no per-machine key, no project signing key.

Built issues whose code goes here: [F209](README.md#f209), [F212](README.md#f212), [F217](README.md#f217)'s VPN part, [F232](README.md#f232), [F245](README.md#f245), [F251](README.md#f251).

## Plan

- Integrate the served replacement paths after [F270](README.md#f270), [F271](README.md#f271), [F272](README.md#f272) and [F273](README.md#f273) provide them. This removal builds against the agreed one-click joining shapes: Core supplies verified person, host and access state and vault unlock; Machines accepts signed state and serves SSH-only services; Gorge uses the person's forge access. These contracts are not built yet. Put them behind fakes, not guessed CLI calls or new file formats.
- **Red first:** extend `test/ui/host_recovery_test.dart` and `test/app/settings_test.dart` with an old saved rental. Restart the app and observe that it remains listed, cannot resume setup or connect using old credentials, and offers only give-back or setup again. A failed give-back must retain the rental and its recovery data. This prevents losing a paid machine or using obsolete trust. Check the explanatory sentence manually; do not assert its text verbatim.
- In `lib/src/app/settings.dart` (`HostUpRecord`, `Settings`), retain a validated legacy record for those recovery actions. Do not discard it when VPN fields disappear from the new record. In `lib/src/app/host_runs.dart` (`HostPreparation`, `HostRuns`) and `lib/src/ui/host_dialog.dart` (`HostDialog`), remove VPN preparation, probes and cleanup phases. Keep give-back confirmation and failure reporting. Setup again enters the replacement server flow and replaces recovery data only after confirmed completion.
- Delete `lib/src/app/host_vpn.dart`, `lib/src/app/own_host_vpn.dart`, `lib/src/ui/host_vpn_dialog.dart`, `lib/src/ui/own_host_vpn.dart` and `lib/src/ui/host_tunnel_export.dart`. Remove their imports, commands and key-copy entry points from `lib/src/ui/shell.dart` and `lib/src/app/commands.dart`. Remove WireGuard `HostTunnel` generation from `packages/porelo_host/lib/src/host_files.dart`. Preserve `lib/src/app/tunnel.dart`: it carries SSH. Remove CA creation, Firefox policy and `/etc/hosts` installation, not SSH host-key verification.
- Remove obsolete needs and feed branches from `lib/src/app/host_stop_feed.dart`, `lib/src/ui/host_stop_dialog.dart`, `lib/src/ui/host_forge_password.dart` and `packages/porelo_host/lib/src/secrets_file.dart`. Adapt `HostPlan` and `HostRun` in `packages/porelo_host/lib/src/host_run.dart`, `PreparedHost` in `host_record.dart`, and requests in `server_contract.dart` to the replacement contract. Refuse an obsolete stop before opening a terminal. Keep unrelated provider sign-ins and secret storage; all remaining secret input stays in its own terminal or provider login.
- Delete `JoinKeys` in `lib/src/app/join_keys.dart` and `AccessLaptop` handling in `access_developers.dart` and `access_join.dart`. Remove pasted host values, key paths and laptop editors from `project_bring_dialog.dart`, `project_join_dialog.dart` and `project_developers_dialog.dart` under `lib/src/ui/`, and their old branches in `ProjectBring`, `ProjectJoin` and `ProjectDevelopers` under `lib/src/app/`. Remove per-machine key generation/import in `lib/src/app/machine_setup.dart` (`MachineSetup`), `SetupRun` in `setup_run.dart`, and the wizard in `lib/src/ui/new_machine.dart`; use the person's identity through their agent. Keep the person’s public identity selection behind Core’s agent boundary. Remove per-machine signing and key-management paths in `machine_binding.dart`, `project_workspace.dart` and `lib/src/ui/project_forge_view.dart`. Replace project-key and `signed_by` inputs in `lib/src/app/project_following.dart` and host setup with verified project-admin signers; never fall back to unverified following.
- Delete walks 17–23 in `doc/walks/`, their obsolete integration tests and `tool/walk23/` helpers. Update walk registration, launchers, packaging dependencies and remaining fixtures that reference removed flows. Delete tests solely for removed behavior; retain and adapt guards for host-key pinning, verified bundles, secret handling and confirmed give-back. Read the final removal against the replacement flows so each operation still has one working entry point.

## Acceptance

- Restoring an old record keeps the host visible with the required explanation. Only give-back and setup again can act on it. A refused or interrupted give-back keeps the record; confirmed give-back removes it.
- A fake-driven setup, register and join round trip reaches the host through SSH and verifies the admin signers without generating laptop keys, requesting a project key, installing trust or opening a VPN root step. A missing signer or refused state stops the action.
- Obsolete stop needs fail before a process starts. Process arguments, protocol output, saved settings and errors contain no secret values. The interface has no secret input form.
- Search the shipped app, host package, package dependencies, tests and walk registration for the removed entry points. Only the deliberate legacy-record reader may retain obsolete metadata; no runnable VPN, CA, key-copy or laptop-editor path remains. SSH forwarding and host-key rejection still work.
- Run the remaining app and host-package unit suites, relevant widget tests and document checks during implementation. Rehearse the replacement path on a local VM once the agreed contracts are available. Fakes alone do not establish interoperability.

## To be checked

- Confirm the final Core signer and unlock API, Machines setup result and stop protocol, and Gorge access interface before replacing the fakes. Check actual fields against the served contract.

## Implementation findings

- Legacy project and server records keep the validated provider project and original rental tag, even when retired trust fields are malformed. Setup again keeps the original lock and tag, refuses a missing existing rental, and replaces recovery only after a checked SSH completion for the same rental. The replacement callback runs while that lock is held and must not reacquire it.
- `PreparedHost` reads the SSH-only completion in one place. `ServerPreparation`, `SignedHostActions`, `ProjectPeople`, and the person-agent identity callback isolate the unbuilt dependencies. No external command or machine-manifest format is invented. Without an adapter the action refuses before renting or changing signed state.
- The wizard lives in `new_machine.dart` and `setup_run.dart`; `machine_switcher.dart` only dispatches it. The plan names the actual callers.
- Walks 17–23, their integration tests, stand-ins and dedicated launchers are retired. Shared feature steps are removed only after checking all retained feature imports.
- Earlier installations can retain numbered or legacy WireGuard interfaces and configuration under `/etc/wireguard`, NetworkManager configuration, host-marked `/etc/hosts` lines, system certificate copies, and Firefox certificate copies and policy. Removing installers does not safely establish ownership of all existing system configuration.

## Deferred

- The unrelated Connections private-key transfer form remains outside host joining; retire it separately.
- Remove obsolete machine-signers explanatory text in the lists rebuilt with [F278](README.md#f278); this round only removes their calls and menu entries.
- Replace the remaining VPN-era SSH and homeserver forwarding paths in `tunnel.dart` and `homeserver_forwards.dart` with [F270](README.md#f270).
- Bind the typed adapters to the served Core signer/unlock, Machines preparation/stop, and Gorge access APIs once available; then rehearse setup, registration and joining on a local VM.
- Retire existing operating-system VPN and trust artifacts through a separately reviewed, ownership-checked migration; this removal does not run root cleanup or delete unrelated configuration.

## Validation

- Targeted frontend runs cover 393 distinct app, widget, feature and document tests; 391 passed in the batch and the two document failures passed after correcting the decision index and retained walk. The final document and fake setup/register/join rerun passed all 24 tests.
- Targeted host-package runs cover 192 distinct tests across eleven files. The final CLI and process-lock rerun passed all 68 tests; the other 124 had passed in the earlier targeted runs. No tests were skipped.
- `dart analyze` and formatting of changed Dart files pass. Feature tests were regenerated with `dart run build_runner build`. The five named document checks pass. A different-model read-only review checked the removal and subsequent fixes against all six requested skills.
- Skills applied: dart-add-unit-test 2026.910.3, dart-write-documentation 2026.910.3, flutter-add-widget-test 2026.911.3, clean-code 2026.906.3, security-audit 2026.906.3 and test-quality 2026.906.3.
- The local VM replacement rehearsal has not run because the served dependencies are unavailable. No interoperability claim follows from the fakes. No full suite, rented-machine run, commit or push was performed.

## Test

Only the change: the remaining tests of the touched files pass; the deleted tests go with their code.

## Estimate

`F276 size=L est=240 basis=guess, no L measured yet`
