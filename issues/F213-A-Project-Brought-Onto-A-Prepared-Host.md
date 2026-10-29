# F213 — A Project Brought Onto A Prepared Host

**Status:** Implementing; blocked by [F208](README.md#f208), [F211](README.md#f211) and [F214](README.md#f214).
**Size:** L - a dialog of its own in the project admin's account, the access repository's checkout and its signed `host:` block, on contracts with two repositories.

**What must be true.** A project admin puts their project on a host they were admitted to, renting nothing: the interface writes the host's values and the project's Matrix settings into the project's private, signed `access.yml`, runs the bring in their own account with no `sudo`, feeds its stop from their own secrets file, and the bring makes the project's room. The host admin takes a project off its server, refused while anything is unpushed; following remains a separate decision.

## Why

Decided: bringing a project is the project admin's act in their own account; `host:`, `developers:` and Matrix's settings live in a second signed file in a private repository, so the public `project.yml` names none of it.

## Plan

- ***Put this project on a server…*** (`project-admin`, `Home.projectMenu`) chooses among hosts this person was admitted to; *The project* step stays, *Where it is rented* goes.
- **The access checkout:** cloned with the person's own git credentials from `access.repository` of the signed `project.yml` into `~/.local/share/porelo-frontend/access/<project>/` (`0700`); never into a log or a support bundle.
- **The `host:` block and Matrix's settings** written into `access.yml` with `yaml_edit` (kept comments), from the values the host admin gave ([F211](README.md#f211)); committed and signed with the person's own git, pushed; the interface signs nothing itself and refuses where git's signing is not set up.
- **The bring:** `ansible-playbook -c local porelo.host.bring -e porelo_project=<project>` over the admin's own ssh, `machine.yml`, `project.bundle`, and `access.bundle` uploaded into their own `~/.local/share/porelo-host/setup/<project>/` ([F214](README.md#f214)), its stop in own-account mode fed from their secrets file: `vault-new` or `vault`, `keys`, `forge-central-token` while a repository is to migrate. Its playbook runs one `sync` and makes the room as its last task.
- **The repositories, agreed with porelo-host:** the bring loads each one as a Forgejo migration from the central
  forge, which keeps its `original_url`; `porelo-host-project remove` compares each repository with that URL and
  refuses only while a commit is on the host and nowhere centrally. The interface gives `remove` only the central
  token on standard input, never a central URL.
- **The room:** the playbook's last task runs `porelo talk room <project>` in the admin's account. The interface
  writes exactly four `transports.matrix` keys: `homeserver` at HTTPS port 8448, `room` as the fixed
  `#porelo-<project>:matrix.<host>.porelo.internal`, `registration_token_file` as the literal
  `~/.config/porelo/matrix/host-registration-token`, and `ca_certificate` as one PEM certificate in a literal
  YAML block. The alias is shown, never edited. The token stays in the admin's own account on the host; the
  interface writes its path only. The CA comes from this host's retained forge CA, checked as one certificate
  whose DER SHA-256 matches its public `ca_sha256`, before any access edit or upload. Missing or mismatched
  trust is refused without a network fetch. No other Matrix key is kept, including `tls_verify` or `ca_file`.
  YAML comments and the exact PEM bytes are preserved. The project file's Matrix peer is not edited here.
  The interface makes no room call and shows the bring's latest public lines; a room refusal stops it in
  Porelo's words.
- ***Take this project off the server*** (`host-admin`): the saved project-to-host association selects the
  retained host record. The existing remove dialog runs `porelo-host-project remove <project>` as root over the
  same pinned helper SSH as registration, with only the central token as one stdin line. Exit 65 refuses
  unpushed work or an unknown project; 73 means the check could not finish, 69 not ready, and 64 usage. Every
  refusal is shown verbatim. Exit zero confirms `project`, `removed: true`, and may report `locked` accounts.
  Nothing changes before the check passes, and removal does not unfollow. *Stop following this project* is the
  separate unfollow. Without the host-admin role or the associated host's record, the reason is that the host
  admin takes a project off its server.
- **Red first:** a widget test that the dialog offers no renting and runs the bring with no `sudo`, against stand-ins for `porelo-host` and git.

## Acceptance

- A project brought onto a host prepared by another person, by its admin alone, follows there in the admin's account, with its room made.
- The public `project.yml` holds no address, key or name of a person; `access.yml` holds them, signed.
- Matrix access has exactly the four agreed keys, the fixed alias and literal token path, and one retained
  host CA whose DER matches `ca_sha256`. A missing or mismatched CA stops before Git or upload. The PEM reads
  back byte for byte in block style, and comments survive removal of unsupported keys and inline mappings.
- *Take the project off* is refused in the helper's words on exit 65, and green on a matching removal reply at
  exit zero. It does not unfollow. Another host's record must not enable removal on the project's host.
- Seen to fail: the widget test red while the dialog still rents.

## To be checked

- A live prepared-host acceptance run against the bring's room task and the root removal helper. Unit and
  widget checks use stand-ins; they do not establish that the host package was published with those contracts.
- The manual integration walk still targets combined setup and is outside this change; it is not bring
  acceptance coverage.

## Implementation

- The project-menu placement action opens a separate wizard with the project, an admitted own-account host,
  public host values, a Matrix room, and the secrets file; no rental step. The existing server-preparation and
  legacy recovery dialogs retain their separate work.
- The signed project's verified revision supplies the project bundle, private access repository, central
  migration URLs, and declared credential names. Invalid migration fields are named without repeating their
  values, before the access edit or any setup upload. A join's machine file still has no forge section.
- The private access checkout preserves comments while updating `host` and `transports.matrix`. Own Git
  credentials and configured commit signing are required. Both old and new access commits are verified against
  the chosen project public key. Dirty work, unpublished commits, another branch, linked access files, and a
  failed push prevent publication or upload; private Git diagnostics are not recorded.
- The bring reuses the own-account upload and stop feed, with both fixed bundle names, checked home paths,
  modes, and digests. It runs the bring playbook over pinned SSH with no sudo, and resumes a successful stop
  without repeating the access push or upload. Only the playbook runs sync.
- The fixed room alias is derived from the project and checked host values. The host's retained public forge
  CA is selected by its Matrix server name, never by a stale connection label or another host's trust. One
  certificate and its DER fingerprint are checked before Git or upload. The four-key Matrix block keeps the
  token path literal and the PEM in block style with exact readback, preserving comments through inline-map
  conversion and removing unsupported keys. The playbook owns creation, and the interface shows
  its final public lines and any refusal, without a separate room step or call. A task with an empty callback
  message still shows its name and state.
- A successful bring records its project-to-host association, read back after writing and preserved on reload.
  The checked host values determine that association, even if the watched connection has a stale host label.
  A failed save retains the previous association. The host admin's project menu resolves only that host's record
  and reuses the root remove dialog with the project fixed for review. Following is unchanged.

## Verification

- Root and package `dart analyze`: no issues. The eight changed Dart files are formatted.
- Package tests: all 477 passed with two workers, including the real system-store tests. None was skipped.
  The package is unchanged; its suite passed before the final YAML review fixes. Root analysis and the
  affected frontend tests were rerun after those fixes.
- The final targeted frontend run passed 65 tests: the changed access unit and real-Git tests, bring widget
  tests, removal and recovery regressions, roles, and layout. The 28 tests tagged `documents` passed.
- The opt-in test `the written Matrix block is accepted by the installed transport settings check` was
  skipped because `porelo-message-transport-matrix` is not on PATH. With the installed binary and
  `PORELO_MATRIX_SETTINGS_TEST=1`, it gives the generated block to `settings` as JSON on stdin and requires
  exactly `"refused": []`. Nothing is installed by the test.
- All five document checks passed: `check-shared`, `check-citations`, `check-readmes`, `check-doc-site`, and
  `check-actions`. Changed files contain no personal home, account, or LAN address. The excluded walk and
  integration files, the issue index, and this issue's Status line remain unchanged.
- The 13 migration tests were observed failing before the implementation, then passing. The credential-name,
  source-URL, and access-branch checks were observed failing before their fixes. Disabling the access-signature
  check made the wrong-signer test fail; restoring the check made it pass.
- The no-rental widget assertion was observed red against the old `HostDialog`, which still offers
  *Where it is rented*, then green against the current project dialog. The test settles after editing before
  pressing Next and keeps real asynchronous work inside `tester.runAsync`.
- Bring widget tests cover the fixed room alias, serialized Matrix block, missing or mismatched host trust
  refused before Git or SSH, own-account upload and stop,
  resuming without a second access push, final playbook lines, and a room refusal in Porelo's words. The separate
  room-step assertion was observed red before that step was removed. An empty successful callback message and
  a stale watched-host label each reproduced a failure before their fixes, then passed.
- The editable room and missing or mismatched CA widget cases went red before the fixed alias and early
  trust check. Disabling CA validation made the missing, chain, non-certificate, extra-DER, and wrong-digest
  tests fail; restoring it made them pass. Literal block style and final-newline readback were seen failing
  before the serialization fix. Comments on removed keys and flow document roots reproduced the read-only
  review findings before their fixes, then passed. The narrow reread found no remaining findings.
- Project-to-host persistence, malformed input, and write-readback checks were observed red before their
  implementation, then green. Removal widget checks cover the correct host record and the helper's exit codes;
  replacing its refusal with generic words made the exit-65 widget test fail, then restoring the helper's words
  made it pass. The real project page exposed a missing removal-tile presentation before it was fixed.
- Existing project-action and recovery tests now cover the added removal command and own-account placement,
  retaining the ended setup's billing recovery instead of expecting rental fields in the project dialog.
- Role, layout, and existing server-admin tests pass. No VM or live-host acceptance run was performed.

## Previous broader frontend checks

The broader frontend run before the exact Matrix settings update finished in 5 minutes 30 seconds with
2,157 passed, 30 skipped, and 19 failed. It exposed
a command-role registry expectation missing the new removal action; the fixed
registry passes in the final targeted run. Eighteen other checks hit environment restrictions: ten in
`test/tool/test_report_test.dart`, two in `test/tool/contract_test.dart`, and two in
`test/tool/mock_daemon_test.dart` select the Snap SDK from the runner's injected path and fail on its read-only
cache. Setting the cached SDK first on the outer process's path did not change the runner's injected prefix.
Four cases in `test/app/host_stop_feed_test.dart` create fixture directories under the read-only home directory.
These are separate from the passing package and targeted frontend suites.

The live frontend checks below were skipped because their daemon, task, project, isolated test vault, or
repository-key opt-in was not configured. No VM or rented-host acceptance was run.

- `client/live_review_test.dart`: a push of several commits is reviewed whole, as the gate view opens it.
- `client/live_daemon_test.dart`: against a running daemon serves an interface this build understands.
- `client/live_daemon_test.dart`: against a running daemon declares every method this client calls.
- `client/live_daemon_test.dart`: against a running daemon declares every name this client sends to and reads from the vault keyslots.
- `client/live_daemon_test.dart`: against a running daemon answers Keyslots with slots this build can read.
- `client/live_daemon_test.dart`: against a running daemon enrolls a device, opens the vault with it, and takes it away again.
- `client/live_daemon_test.dart`: against a running daemon declares every name this client sends to and reads from held messages.
- `client/live_daemon_test.dart`: against a running daemon declares every name this client sends to and reads from peers and what a person says.
- `client/live_daemon_test.dart`: against a running daemon answers Held with messages this build can read.
- `client/live_daemon_test.dart`: against a running daemon answers a message that is not there with NO_SUCH_MESSAGE, and decides nothing.
- `client/live_daemon_test.dart`: against a running daemon reads a message held for a person in full, and refuses it for good.
- `client/live_daemon_test.dart`: against a running daemon answers List with tasks this build can read.
- `client/live_daemon_test.dart`: a project whose repositories name agents names each repository's agent, and one click starts exactly those, attended.
- `client/live_builds_test.dart`: Watch brings the task's builds to what its tile must say.
- `client/live_hand_in_test.dart`: against a running task a small file is placed whole, listed with who handed it in.
- `client/live_hand_in_test.dart`: against a running task a large file goes in parts and is placed whole.
- `client/live_hand_in_test.dart`: against a running task a transfer cut off after one part resumes where the machine holds it.
- `client/live_hand_in_test.dart`: against a running task a second file under a name still in flight is refused, with how far the first got.
- `client/live_hand_in_test.dart`: against a running task a file over the task's limit is refused before a byte is sent.
- `client/live_hand_in_test.dart`: against a running task a file taken back is gone, and the record says given and taken back.
- `client/live_hand_in_test.dart`: against a running task a Watch opened before a hand-in sees the file arrive and go.
- `client/live_hand_in_test.dart`: the record is still there after the task is removed.
- `client/live_refresh_test.dart`: a followed project is fetched now, and its record says when.
- `client/live_refresh_test.dart`: a project this account does not follow is refused by name.
- `client/live_refresh_test.dart`: "Check it now" says the follow and each repository, as the page shows them.
- `client/live_refresh_test.dart`: a task is brought up to its source, with what moved and whether its agent heard.
- `client/live_refresh_test.dart`: a repository started in a checkout says so, with the checkout as where its work goes.
- Live earlier-work check: a new task whose earlier work waits is refused in words, naming that work.
- Live forwarded-branch check: a push forwarded onto a taken branch is refused in words, and still waits.
- `app/published_key_test.dart`: the repository serves the key whose fingerprint this build carries.

## Assumptions

- Admitted hosts are existing watched `kind: host` connections with the person's own login, identity, and pinned
  trust. The bring does not infer admission from an account name or grant it.
- The chosen project public key verifies both the project revision and the access commits. Git's configured
  signer must produce a matching signature; the interface does not choose or replace the person's signing key.
- The host package follows the agreed room and removal contracts. Its installation and publication are checked
  separately from the interface's unit and widget tests.
