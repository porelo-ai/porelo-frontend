# F251 — Firefox Reads The Policy The VPN Wrote

**Status:** Accepted.
**Size:** XS - the VPN's root step leaves `/etc/firefox` and everything it writes under it readable by every account, and refuses a folder Firefox cannot enter.

**What must be true.** After the VPN for a server is set up, `/etc/firefox`, `/etc/firefox/policies` and `/etc/firefox/porelo` are root-owned with mode `0755`, and `policies.json`, the managed policy and each CA copy are root-owned `0644`. Firefox started by the person afterwards shows *about:policies* as active, with the server's CA under *Certificates*. A folder in that path that the step cannot make readable stops the step, naming the folder.

## Why

Operator's walk 23 on VM A (2026-10-30): *about:policies* said "The Enterprise Policies service is inactive". The VPN's root step had left `/etc/firefox` as `root:root 0700`, so Firefox running as walkadmin could read neither `/etc/firefox/policies/policies.json` nor `/etc/firefox/porelo/`. The operator imported the CA by hand (Porelo walk9server CA, SHA-256 `42:AF:8E…B4:AA:78`), to be removed in the walk's cleanup.

`install -d -m 0755 /etc/firefox/policies /etc/firefox/porelo` (`lib/src/app/host_vpn.dart`) sets the mode of the two named folders only; the parent it creates on the way takes the process's umask, and an existing parent keeps whatever mode it has.

## Plan

- In `_firefoxPolicyStep`, make `/etc/firefox` first with `install -d -m 0755`, then set `0755` on `/etc/firefox`, `/etc/firefox/policies` and `/etc/firefox/porelo` whether they were made now or found, and refuse a path among them that is a link or not owned by root.
- The CA copy (`install -D -m 0644` near `firefox_ca=`) no longer makes folders on its own: they exist by then.
- **Red first:** the generated step run in a scratch root under `umask 077` leaves the three folders `0755` and the files `0644`; a test that an existing `0700` `/etc/firefox` is made `0755`.

## Acceptance

- On a machine whose `/etc/firefox` was `0700`, the VPN set up again leaves it `0755`, and Firefox as the person shows *about:policies* active with the server's CA.

## Test

Only the change: the tests above and `host_vpn`'s own tests. The VM check is the one *about:policies* look on VM A, after removing the hand-imported CA. No full walk.

- The generated shell runs without root in a temporary folder with its system paths redirected there.
  Under `umask 077`, both a missing Firefox parent and an existing `0700` parent fail before the fix
  with mode `0700` instead of `0755`; the fixed step leaves all three folders `0755` and its files `0644`.
- The shell rejects linked folders before copying the CA and names a folder whose permissions cannot
  be repaired. Ownership is checked against the effective account, which is root in the sudo step and
  the test account in the scratch execution.
- Existing matching CA copies with mode `0600` become `0644`; linked CA copies are refused by path
  without changing the target's contents or permissions. The policy includes only owned regular CA
  files, excluding links and directories.
- Take-down returns zero with unmanaged or linked policies and a linked Firefox parent, preserving
  the policy and directory permissions without creating the CA folder.
- Foreign ownership cannot be created by the unprivileged scratch execution: changing a folder's
  owner to root fails. Linked-folder and linked-CA cases exercise refusal without privileged fixtures.
- The seven added regressions fail against the original step or deliberate mutations; the mutations
  are restored before the passing run. The changed code is read against `dart-add-unit-test` and
  `dart-run-static-analysis`, both version `2026.910.3`.
- Targeted checks pass: `host_vpn_command_test.dart` (54), `host_vpn_probe_test.dart` (5),
  `host_vpn_save_path_test.dart` (7), and `host_vpn_test.dart` (36). None are skipped.
  `dart analyze` reports no issues; plain `dart format` completes on changed Dart files.

## To be checked

- On VM A, remove the hand-imported CA, repeat VPN setup, and confirm root ownership and active
  *about:policies* with the server's CA. This privileged browser check has not run in this worktree.

## Estimate

`F251 size=XS est=10 basis=median XS 10 (F151 F198 F201 F202 F222 F225 F227, 8 records)`
