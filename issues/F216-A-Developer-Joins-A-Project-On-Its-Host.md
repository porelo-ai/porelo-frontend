# F216 — A Developer Joins A Project On Its Host

**Status:** Review.
**Size:** L - the join's steps from a signed file to a working account, the laptop's keys, and their tests.

**What must be true.** A developer whom a project's signed access file lists joins it on its host with nothing handed over: the interface checks the file, brings this laptop's own VPN up with its address from the list, trusts the host's CA by its signed fingerprint, pins the host key, and runs the join in the developer's own account; *Copy my public keys for <host>* gives a project admin what the list needs.

## Why

Decided: developers come from the signed access file; the hand-carried access request and access file go for them.

## Plan

- ***Copy my public keys for <host>*** (`user`): this laptop makes that host's ssh key and WireGuard key (private halves in the system secret store, as the VPN key today) and copies the public halves as one text block with no ssh comment.
- ***Join this project on its host*** (`user`):
  1. clone the access repository with the developer's own read access; without it, say so, naming the repository and GitHub's invitation, and change nothing;
  2. a local `porelo` runs `project verify --json --access-repository … [--access-since …]`; where Porelo is missing, say "Install Porelo on this computer" and stop; the laptop keeps the commit it joined at;
  3. read `transports.matrix.ca_certificate` from `access.yml` at the `access_commit` Porelo verified and check its DER SHA-256 against `host.ca_sha256` ([F212](README.md#f212)); refuse a mismatch with both fingerprints before creating persistent join state or exporting this laptop's SSH identity;
  4. the VPN for this host with this laptop's `vpn_address` ([F209](README.md#f209)); no SSH connection runs before it is up;
  5. the ssh host key pinned from `host:`;
  6. `ansible-playbook -c local porelo.host.join -e porelo_project=<project>` in the developer's own account, using `machine.yml`, `project.bundle`, and `access.bundle` from `~/.local/share/porelo-host/setup/<project>/`, its stop in own-account mode ([F214](README.md#f214)): their vault, the gate's and agents' tokens from the helper's file, their lasting forge password, their own forge write token for the gathered push.
- **Locked:** a developer the list dropped is told the host refuses them, and offered nothing to repair.
- **Red first:** a test that an access-file CA whose SHA-256 differs from `ca_sha256` is refused before the root step, and that no step runs or persistent laptop files change before `project verify` answers.
- **Implementation:** `lib/src/app/access_join.dart` reads the verified access answer independently of the developer-list writer; `join_keys.dart` keeps this laptop's keys; `project_join.dart` sequences verification, trust, VPN, password, upload, and the existing own-account playbook runner. `lib/src/ui/project_join_dialog.dart` supplies the user wizard and public-key copy action; the commands live in `commands.dart` and are wired through `shell.dart`. The VPN exporter accepts the selected laptop address instead of fixing it to `.2`.
- **Laptop tools:** `porelo` with `project verify --json`, `wg`, `wg-quick`, `keepassxc-cli`, `ssh`, `scp`, `ssh-keygen`, `git`, `sudo`, Bash, and the Linux system tools checked by `checkHostVpnRootTools` (`sh`, `ip`, `ping`, `cat`, `install`, `date`, `sleep`, `awk`, `cmp`, `mktemp`, `chmod`, `mv`, `rm`, `grep`, `head`, `tail`, `sed`, and `base64`), plus `id`, `stat`, and `mkdir`. System CA installation uses `update-ca-certificates` or `update-ca-trust`; NetworkManager's `nmcli` is optional. Ansible is required on the host, where the join runs; it is not required on the developer's laptop. The walk checks these tools before rehearsal.

## Acceptance

- A developer listed in the signed file joins with no file handed over and starts their agents there ([F148](README.md#f148)).
- A tampered `access.yml` or a wrong CA is refused before anything on the laptop changes.
- Seen to fail: the CA test red before the fingerprint is checked.

## Notes

- The CA comes from `git show <access_commit>:access.yml` in the private clone, under `transports.matrix.ca_certificate`. Its digest and certificate structure are checked before persistent join state or an SSH identity is written. Developer SSH keys admit connections only from their listed VPN address, so every SSH call waits for the VPN and uses the host's VPN address and its own pinned `known_hosts` file.
- Verification uses disposable private files outside `joins/<project>`. The access bundle carries both `HEAD` and the origin's default branch at the verified access commit; a different clone or branch tip is refused before laptop setup.
- A developer with no rental record keeps an explicit VPN-only host record. It survives a settings reload without invented provider or setup identity data, and an existing full host record keeps its recovery fields. A malformed record is refused without a null assertion.
- Joining is unavailable without KeePassXC's command-line reader or a selected secrets file, with the missing prerequisite explained.
- Private SSH and WireGuard halves have their lasting source in the system secret store. SSH uses an owner-only identity restored under `XDG_RUNTIME_DIR`; the VPN uses its existing private runtime export and root installation.
- The verified access commit is retained after the host daemon confirms the joined project revision and is supplied as `--access-since` on the next join against the same access repository.
- The two required guards in `test/app/project_join_test.dart` were seen failing after deliberately moving identity restoration before the verification answer and CA validation after the VPN/root boundary. The guards were restored.
- Local service and widget tests use process and SSH stand-ins. A real join requires a Porelo snapshot exposing `project verify` and a host collection exposing `porelo.host.join`, own-account stops, and the own-login forge-password helper. The full build and two-laptop rehearsal remain unvalidated; the current checks cover only changed files and their tests.
- Regression tests reproduced premature public-address SSH, a null assertion with no prior host record, an access bundle containing only `HEAD`, acceptance of a different access tip, persistent writes before verification, and both missing join prerequisites. The written-pin guard was seen failing after a deliberate public-address pin mutation, then restored.
- Scoped validation of the corrections: 100 tests pass, none skipped, covering the join, saved VPN records, settings and their store, command roles and availability, VPN UI, and copying public keys. Analysis of the eight changed Dart files reports no issues. Tests use the shared SDK serially, including a real Git bundle/ref check. No Maven, full-suite run, or live two-laptop acceptance is included.
- The correction diff received a read-only review against `dart-add-unit-test` and `dart-write-documentation` 2026.910.3, `flutter-add-widget-test` 2026.911.3, and `clean-code`, `security-audit`, and `test-quality` 2026.906.3; no findings remain.

### Deferred

- Automatic restoration of a watched account's runtime SSH identity after a laptop reboot.
- General access-schema networks beyond the prepared host's existing `10.73.<n>.0/24` contract.
- The project-admin bring's lasting-password terminal, outside the developer join.
- Broader test-environment findings from interrupted checks: the forge-token PTY timeout, isolated keyring DBus refusal, and host-stop fixtures that write beneath the account's home.
- Sharing `openHostVpnDialog`'s Snap check and failure-line reporting with the join's VPN terminal.
- Adding the join to the Projects page row menu.
- Consolidating the duplicated `10.73` address validator.
- Replacing `JoinKeys.publicKeys`' call to `HostFiles.prepare` with placeholder arguments.
- Whether porelo-intellij reads a joined host's per-host `known_hosts` file.
- From the read-only harm review of the fixes, outside "What must be true": the clone-tip refusal test changes
  HEAD, branch and bundle at once, so each comparison is not seen failing alone; `currentTip` repeats the
  `rev-parse HEAD` `_bundleAccess` already did; the "all SSH waits for the VPN" test does not watch uploads
  (`JoinRemote.copy`); the watched machine's known_hosts test compares a reported path, not the written pin;
  the dialog's call that records the host after a verified VPN has no test of its own.
