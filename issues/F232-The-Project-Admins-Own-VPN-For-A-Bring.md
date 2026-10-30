# F232 — The Project Admin's Own VPN For A Bring

**Status:** Implementing; blocked by [F213](README.md#f213) and [F216](README.md#f216).
**Size:** S - the bring's first step on a project admin's own machine, reusing the join's VPN step and the CA check.

**What must be true.** A project admin brings their project onto a host from their own machine, which is not the host admin's: from the host values the host admin copied for them, their own address on the host's VPN and the keys *Copy my public keys for a host…* made on this machine, the bring brings this machine's VPN to that host up, fetches the host's CA through it and trusts it only when its SHA-256 equals `ca_sha256`, records the host, and only then brings the project.

## Why

Decided (operator, 2026-10-30): walk 23 has the project admin on a machine of its own, so that the host admin's laptop holds no project admin's role. A VPN peer per person is allowed only while the project's own repositories move onto their hosts; ssh alone replaces it later ("Only ssh reaches a host in normal work").

## Plan

- The bring dialog ([F213](README.md#f213)) gains, before the bring, a step for a machine with no record of this host: the pasted host values, this machine's VPN address on that host (`10.73.<n>.<k>`, not the host's `.1` and not the host admin's `.2`), and this machine's keys for the host from *Copy my public keys for a host…* ([F216](README.md#f216)).
- The VPN comes up as the join's does ([F216](README.md#f216)), with this address and the host block from the pasted values.
- The CA is fetched over ssh through the VPN from `/etc/porelo-host/forge/ca.pem`, in the project admin's own account, pinned to the pasted `ssh_host_key`, and kept only when its SHA-256 equals `ca_sha256`; otherwise refused showing both fingerprints, before anything else changes.
- The host is recorded as the join records it, so the bring and later acts find its CA and VPN.
- A machine that already has this host's record and VPN goes on to the bring as today.
- **Red first:** a test that a CA whose SHA-256 differs from `ca_sha256` is refused and the bring does not start; and that the VPN step runs with the address given and the pasted host block.

## Acceptance

- On walk 23's VM A, walkadmin brings walk6-demo onto walk6 with nothing on that machine but the pasted values, its address and its copied keys.
- A wrong CA stops the bring with both fingerprints shown, before any change.

## Notes

### Built

- The bring wizard asks for this machine's VPN address when the pasted host has no local record. It rejects the host's .1, the host admin's .2, other networks, and unusable subnet addresses, and restores the existing copied host keys without creating replacements.
- `connectOwnHostVpn` and `openOwnHostVpn` share the join's VPN setup, fresh-handshake check, temporary-file cleanup, verified CA installation, and host recording. A join still uses its verified access-file CA in one activation.
- A first bring connects without installing a CA, fetches `/etc/porelo-host/forge/ca.pem` through own-account SSH to the VPN address using the pasted host key in this host's own pinned `known_hosts`, then verifies the CA before installing trust, recording the host, or constructing and publishing the bring's access settings. A mismatch shows expected and received SHA-256 fingerprints without displaying fetched text or SSH diagnostics.
- Existing host records retain the existing bring path. A same-dialog retry retains the restored SSH identity. The existing bring widget test covers the new step, a successful first bring, address refusals, and the fetched-CA mismatch.

### Tests

- Red first: `a fetched CA mismatch shows both fingerprints and prevents the bring` compiled and failed because the old path returned the missing-CA refusal instead of the expected fingerprint. `a new bring connects the supplied laptop address and pasted host before constructing its source` compiled and failed because no VPN activation occurred. Both pass with the new path.
- The six shared-flow guards were seen to fail at runtime after deliberately breaking refusal handling, address forwarding, CA validation, trust-file link rejection, and diagnostic filtering; all mutations were restored before the green run.
- Local unit and widget tests: 54 passed, none skipped, across `test/app/own_host_vpn_test.dart`, `test/app/project_bring_validation_test.dart`, `test/ui/project_bring_test.dart`, `test/app/project_join_test.dart`, `test/app/join_vpn_record_test.dart`, `test/app/command_roles_test.dart`, and `test/features/application_shell_test.dart`. Local sockets worked. The application-shell pointer scenario emitted an appearance-menu hit-test warning and passed.
- `dart analyze --fatal-infos` on the nine changed Dart files: no issues. Formatting and `git diff --check` passed.
- Read-only review against the applicable skills found no actionable in-scope defect; the ordering of the CA fetch, fingerprint check, trust, recording, and bring, and the join's single activation were checked in the code.
- Skills applied: `dart-add-unit-test`, `dart-run-static-analysis`, `dart-use-path-package`, `dart-use-pattern-matching`, and `dart-write-documentation` at `2026.910.3`; `flutter-add-widget-test`, `flutter-apply-architecture-best-practices`, `flutter-build-responsive-layout`, `flutter-fix-layout-issues`, and `flutter-implement-json-serialization` at `2026.911.3`.
- Not run: the live VM acceptance with a real VPN, sudo terminal, system CA stores, SSH host, and bring; the full workflow and document checks. Verification is limited to the requested targeted local tests and static checks.

### Deferred

- Automatically restoring copied host keys when reopening a bring that already has a local host record.
- Replacing machine-specific examples elsewhere in the repository; none were added by these changes.
