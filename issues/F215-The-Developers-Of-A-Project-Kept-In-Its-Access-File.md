# F215 — The Developers Of A Project Kept In Its Access File

**Status:** Review.
**Size:** L - a settings section editing a signed file, the forge's API for read access, and the states read from host and forge.

**What must be true.** A project admin keeps the project's developers in its settings: each with an account name on the host, their login at the central forge, and one or more laptops with their public keys and VPN address; the change is signed with the admin's own git, the developer gets read access to the access repository, and each developer shows what the host and the forge say of them.

## Why

Decided: the developers are listed with their public keys in the project's signed access file; bringing the project admits every listed developer, and a change to the list adds or removes them on the host automatically.

## Plan

- ***Developers***, a section of the project's settings (`project-admin`), on the access checkout ([F213](README.md#f213)):
  - **Add:** the account name within `porelo-host`'s pattern, `forge_login`, then laptops: each from a pasted key block (*Copy my public keys*, [F216](README.md#f216)), checked as an ssh and a WireGuard public key, the ssh comment stripped, with the next free `vpn_address` of the host's network proposed.
  - **Remove** a developer or one laptop.
  - Written with `yaml_edit` (declared in `pubspec.yaml`, not used yet), committed and signed with the person's own git, pushed.
- **Read access:** `GitHub` in `lib/src/app/forge.dart` gains the collaborator calls: `PUT /repos/{owner}/{repo}/collaborators/{login}` with `permission: pull`, `DELETE` on removal, and reading the pending invitations. A token without the right is refused with the right named; a forge with no such API gets a link saying what to grant.
- **The states:** *listed*, *admitted*, *locked* or *refused with the helper's reason*, read from the host; *invited* or *can read*, read from the forge.
- **Red first:** a test that adding a developer writes exactly one entry into a fixture `access.yml`, comments kept, and calls the collaborator API once.

## Acceptance

- A developer added here is admitted on the host after the signed commit lands, and can clone the access repository once they accept GitHub's invitation.
- A developer removed is locked on the host and loses read access.
- No private key, no comment of a key, and no token appears in the file, a log or the screen.
- Seen to fail: the fixture test red before the section exists.

## Notes

- The shared reader is `parseAccessDevelopers` in `lib/src/app/access_developers.dart`; the same file exposes
  public-key block parsing and the comment-preserving developer writer for [F216](README.md#f216).
- The fixture test was seen to fail with an empty developer mapping before implementation. It now checks one
  entry, preserved comments, stripped SSH comments, and exactly one `permission: pull` collaborator request.
- Host application is confirmed only when the admin sync reports the published access commit. The panel shows
  the last sync answer and keeps an earlier answer after a refusal; it does not infer locked from dropped.
- Publication is recorded before local cleanup or bundle creation, so external application remains retryable
  after a local failure. A pending operation keeps its reviewed revision; refreshing it is refused until retry.
- Applied skills: `dart-add-unit-test` and `dart-write-documentation` 2026.910.3;
  `flutter-add-widget-test` 2026.911.3; `clean-code`, `security-audit`, and `test-quality` 2026.906.3.
- Independent read-only review found three defects, each reproduced by a failing test and corrected:
  publication lost after local cleanup failure, a refresh replacing a pending operation's revision, and
  unsupported pasted YAML exposing secret input. The final fix review has no remaining findings.
- Before interruption, the focused access and widget group passed 49 tests; the project-bring regression
  group passed six, and the admin-sync boundary group passed four. The skipped test was
  `the written Matrix block is accepted by the installed transport settings check`, which needs the installed
  Matrix transport. Seven deliberate code mutations were caught by their tests and restored.
- Recovery verification: analysis of all 30 changed Dart files passed. The serial targeted runtime rerun
  stopped before executing tests because the sandbox refused Flutter's loopback server socket with
  `Operation not permitted`. No Maven or full-suite run was started during recovery.

## Deferred

- Independent live listed, admitted, and locked queries require a read-only host helper contract; the current
  panel reports the signed list and last admin sync answer.
- Revoking inherited organization or team repository access requires a separate forge permission decision.
- Persisting unfinished host or forge operations across settings sessions requires a durable operation record.
- The full build and live two-laptop acceptance remain unverified: host admission and locking, GitHub
  invitation acceptance, cloning, and loss of read access need the operator's build and walk.
- From the read-only review, outside "What must be true": the parser tests' leak check uses a value absent from
  three of its cases; the developer tests use a fake access checkout instead of `RunHere` under a real one.
- From the read-only review: a manual host sync with nothing published, or one answering another admin's newer
  commit, leaves Retry pending and the list locked; a developer removed and added again in one session shows as
  both listed and removed; after a failure past the push the add wizard offers no Retry (the list's Retry does).
- From the read-only review: for a non-GitHub repository whose path has more than two segments, the manual-grant
  button is enabled but does nothing; `root` as a developer account is refused only by the host sync, after the
  signed push.
- A refusal while opening the developer settings is now shown in place of "Opening developer settings…"; it
  has no widget test, since the opening path reads the system secret store.
