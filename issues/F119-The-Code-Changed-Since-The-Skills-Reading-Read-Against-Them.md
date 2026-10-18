# F119 — The Code Changed Since The Skills Reading Read Against Them

**Status:** Review; read, and built in its three parts [F125](README.md#f125), [F126](README.md#f126) and
[F127](README.md#f127), each in Review with it, published as `0.5.1~snapshot.159`.
**Size:** XL - 860 files read, thirty findings with their sites, built as the three parts of L or
smaller; this issue keeps the reading and its findings, and is finished when the three are.

**What must be true.** Every line of Dart in this repository has been read against the sixteen skills
`AGENTS.md` names, each at a recorded version and SHA-256. Every finding was either fixed, with a test
seen to fail first where it prevents a harm, or declined with its reason written here.

## Why

The whole of `lib`, `test`, `tool` and `integration_test` was read against the skills once, in
`17d641f`, which survives only on the local branch `pre-public`; `main` holds it inside `81b91e9`.
Everything written since has not been read against them. Neither that reading nor its issue
recorded which version of each skill it used.

## Plan

- **The scope** is `git diff 17d641f main -- lib test tool integration_test`, read as whole files
  where a file is new (598 of the 860) and as changed hunks with their surroundings otherwise:

  | Directory | Files | Added | Removed |
  |---|---|---|---|
  | `lib` | 103 (43 new) | 17,228 | 1,522 |
  | `test` | 672 (481 new), 60 % of it `test/features/step` | 17,661 | 1,016 |
  | `tool`, `integration_test` | 85 (74 new) | 2,521 | 28 |

- **The skills, as published now**, each checked against its SHA-256 before it is loaded; the
  versions are read again when the reading starts, and the ones used replace these:

  | Skill | Version | SHA-256 |
  |---|---|---|
  | `dart-add-unit-test` | 2026.910.3 | `3b22d9d1470459b3a7103f243ef6605a6dcf4f30910b658bc22ac9897526ca70` |
  | `dart-build-cli-app` | 2026.910.3 | `9e9caed5bf1e1f06d1bc2764bf401d325cfe16c0003fd8b857c052a4d2f8e3f5` |
  | `dart-collect-coverage` | 2026.910.3 | `6b6cefc79000d2398499a3ed4bb1c7d9aafaf10eb913edaf7644e74147a7dcf9` |
  | `dart-generate-test-mocks` | 2026.910.3 | `36d04ce566bc38f336d676c2c911857203dcefc1833761deadfdf8c5318ffafb` |
  | `dart-resolve-package-conflicts` | 2026.910.3 | `f3eaa18571b5296e9b5efcaeeecc98de8fb7e37e8dfe9abd6a3141aef19a2fc6` |
  | `dart-run-static-analysis` | 2026.910.3 | `925dfd8160f369ac81b440c6be4cc69c10998efeb5a82a531b2a3559ce61b522` |
  | `dart-use-path-package` | 2026.910.3 | `d2f12524f4d6efbb8eed712e767db984aa5b483651157d5a0fd7749dfac647cd` |
  | `dart-use-pattern-matching` | 2026.910.3 | `7f62381040acff9754a7be771686d4d18d69508578ea6f56169b6c0d5f6ac8f2` |
  | `dart-use-primary-constructors` | 2026.910.3 | `b8879260c8b8c959022a3ed70094ca9f58aaaf7f7dfae9b65cf5513adfa56f67` |
  | `dart-write-documentation` | 2026.910.3 | `2cc50c5611094d630c272798fc22ff77f3e5166d4618e7ef398c6a830b06f716` |
  | `flutter-add-integration-test` | 2026.911.3 | `6cf6706ec7d998097711adbc2a00ca016b613d17a5b2044f0e0b9850aee622b4` |
  | `flutter-add-widget-test` | 2026.911.3 | `c0918f867e3c9de492929bf1446f03a39a2f74e6aa0a991fa6fbcbb44a16751b` |
  | `flutter-apply-architecture-best-practices` | 2026.911.3 | `fd37725ebf2a7715fa121a94fb91e7a65e75987a2bbe7f79188eb8513b6e4cf9` |
  | `flutter-build-responsive-layout` | 2026.911.3 | `cfb5fd5fc320ba534950b644638c7db1f032c3bb0b6fa7ce259997e94a69d0cc` |
  | `flutter-fix-layout-issues` | 2026.911.3 | `d3ae723b488c2dab47ed7aa815eef128b5263e5d6ffc9608ba7b2ed489a90930` |
  | `flutter-implement-json-serialization` | 2026.911.3 | `2bdc1a68726438346f5efec715a783d432f5dac02d7b92264307f3bb78545ce1` |

- **The order**, from what reaches a daemon outward: `lib/src/client`, `lib/src/app`, `lib/src/ui`,
  `lib/src/mock`, `tool`, then the tests (`dart-add-unit-test`, `flutter-add-widget-test`,
  `flutter-add-integration-test`, `dart-generate-test-mocks` weigh most there).
- **A finding** is fixed, with a test seen to fail first where it names the harm it prevents, and
  without one where it names none, as the shared rule on what is tested says. Otherwise it is declined
  here with its reason. Where a skill contradicts a rule measured here, it is added to the decision "Where a Dart
  or Flutter skill says otherwise" in `doc/decisions.md`, which already settles tolerant readers,
  non-enum backend values, the layout of `lib/src`, `World.settle`, stand-ins instead of `mockito`
  and `integration_test` under xvfb.
- **`shellcheck` on each tracked `*.sh`** (`tool/e2e.sh`, `tool/package.sh`), as part of the reading,
  since what it finds can change behaviour. Each finding is fixed in the cleanup commit, with a test
  seen red first where one can be; one left as it is gets `# shellcheck disable=<code>` with its
  reason on the line above. The host has no `shellcheck`; its version is recorded here when it runs.
- **`persist-credentials: false` on every `actions/checkout`**, the five in `build.yml`,
  `windows.yml` and `shared-rules.yml`, in the cleanup commit: no step pushes with git, so the
  read-only token need not stay in `.git/config`. `check-actions` refuses a checkout without it once
  porelo-buildtools carries that.
- **No interface another repository reads changes:** not the calls and fields of
  `org.fuin.porelo.Tasks1` and `Tasks2`, the settings file `porelo/frontend.json` the IntelliJ plugin
  reads, the packages' names and paths, the desktop and MSIX ids, or the instance socket. A finding
  that would change one is not built; it is named in the channel and here.
- **Red first:** each harm's test, seen to fail on `main` before its fix.
- **Which part takes what:** findings 1-12, the strict analyzer modes and the documentation in
  `lib/src/client` and `lib/src/app` go to [F125](README.md#f125), with `porelo/frontend.json` keeping its unknown
  keys; 13-24, the colours, the walks in English, `persist-credentials` and the documentation in
  `lib/src/ui` to
  [F126](README.md#f126); 25-30 and the skill named in `doc/decisions.md` to [F127](README.md#f127).

## Findings

Read on `7c38e4e` against the sixteen skills at the versions above, each zip's SHA-256 matching this
table and `agent-skills`' storage API, none newer; each `SKILL.md` read from outside the repository,
since the harness cannot install them here. `shellcheck` 0.11.0. Each finding is a guess until its
test is seen red; none is fixed before [F124](README.md#f124). *Probed* means reproduced in a scratch
copy.

**`lib/src/client`, `lib/src/app`:**

1. **GitHub Enterprise is asked at the wrong path** (`forge.dart`, eight calls): `_api.replace(path:)`
   drops `/api/v3`, so `whoAmI` asks `https://<host>/user`. *Probed.*
2. **A forge's failure escapes as an exception nothing handles** (`forge.dart`): a 2xx that is not
   JSON, a body of another shape, a TLS or HTTP exception; the callers catch only `ForgeRefused`, so a
   button's future fails unhandled and `stillAsking` never reaches 0. *Probed.*
3. **Forge requests have no time limit** (`forge.dart`, `_Network`): a forge that stops answering
   leaves the form busy for good.
4. **Three wire fields are read with a bare cast** (`models.dart`, `DefaultRepository.source` and
   `remote`, `TaskRefreshed.moved`), against the tolerant-reader rule. *Probed.*
5. **A bundle that is not base64 throws out of the review** (`porelo_client.dart`, `pendingBundle`).
6. **A hand-in whose file cannot be read stays busy for good** (`hand_in.dart`). *Probed.*
7. **A homeserver forward raised after `dispose` is never closed** (`homeserver_forwards.dart`), and
   overlapping checks can raise two forwards for one port. *Probed* (the first).
8. **The WSL package-key check takes the first key of the file only** (`wsl_setup.dart`): a file with
   the right key first and another after it passes, and both go into apt's keyring. *Probed.*
9. **On Windows a WSL machine counts as this computer** (`machines.dart`, `isThisComputer`, both
   sockets `''`): a silent distribution is never under *Needs you*, and *Start Porelo* runs `sh`.
10. **The forge workspace assumes Linux** (`project_workspace.dart`): `$HOME/.ssh`, and a `chmod`
    outside the `RunHere` seam.
11. **The stand-in's `Stop` answers `surviving` as a list**, where the client reads a count
    (`mock/machine.dart`).
12. **Two machines of one name in a hand-edited `porelo/frontend.json` are both kept**
    (`settings.dart`, `machines()`); the second is to be dropped as an unusable entry is.

**`lib/src/ui`:**

13. **Two task-less tiles on one machine share a `GlobalKey`** (`work_page.dart`): two questions for
    tasks not listed yet throw "Duplicate GlobalKey"; the key map is never pruned.
14. **The WSL probe leaks its connection on a timeout, and a view opens a socket**
    (`wsl_machine.dart`), against "only `lib/src/wire` and `lib/src/client` open a socket".
15. **Models and controllers never disposed:** six `TextEditingController`s per draft
    (`destinations_view.dart`), `WslSetup`, the shell's own `ForgeConnection` and each
    `MachineClearing`.
16. **A model used after it is disposed:** `setState` after `dispose` in `destinations_view.dart`;
    `MachineBinding` and `TaskPeers` notify after their dialog disposed them mid-call.
17. **`SessionView` keeps listening to the old session** when another is shown in its place (no
    `didUpdateWidget`).
18. **A tile's console asks for the screen every 3 s with no guard**, so slow answers queue on the
    machine's one connection (`tile_console.dart`).
19. **Dialogs that do not scroll overflow on a short window:** the words dialog, *Forget* with an ssh
    entry, and *Which branch*.
20. **Repository lists are built whole**, each row asking `usedOn` on every rebuild
    (`forges_page.dart`, `repositories_view.dart`).
21. **Cancel does nothing** on the forge form in two places (`onDone: (_) {}`).
22. **The terminal diagnosis writes synchronously and rebuilds every line on each event**, and joins a
    path by hand.

**`tool`:**

23. **`tool/e2e.sh:24` exports an empty user or socket** from a lease file that lacks one, and runs on
    (`shellcheck` SC2155). Its two SC2329 notes are trap handlers: kept, with the reason.
24. **`tool/windows-package.ps1` writes the signing key to `RUNNER_TEMP` and passes its password on
    `signtool`'s command line**, against "a secret never appears in a command line … never touches a
    filesystem in CI". The fix signs from the certificate store, loaded from memory.

**The tests:**

25. **A red integration run leaves the VM account dirty:** cleanup is each scenario's last step,
    never a tear-down, and several cleanup steps cannot fail (`|| true`, `rm -f`, an unchecked
    `unfollow`); `matrixInTheAccount` and the stub agent stay installed.
26. **A step leaves a `lib` static at zero**: `StartWork.askAgainAfter`, for every later scenario.
27. **`pumpAndSettle` in `World.fromARepositorysMenu` and six steps**, against "steps settle with
    `World.settle`"; `settle`'s own doc now heads another method.
28. **Tests that pass with what they test removed:** `it_says_keeps_running` (half the sentence),
    `the_repositories_are_listed_a_card_each` (0 = 0), Check it now in `live_refresh_test`, the rpm
    half of the index wait in `workflow_publish_test`, `probe_look_test` (the record, not the colour),
    `held()` in `live_daemon_test`, the IDL declaration check there (cut at the second `)`, no word
    boundary), the probe step, and two `textContaining` over the whole screen.
29. **Tests that reach the host:** git without `GIT_CONFIG_GLOBAL`/`NOSYSTEM`
    (`project_workspace_test`, `features_named_test`), the tunnel tests through a login shell and its
    `/etc/profile`, three steps on `DateTime.now()`.
30. **Clean-up and independence:** disposals after the expects (`homeserver_forwards_test`,
    `modified_keys_test`, `relay_test`, `terminal_copy_test`), `live_hand_in_test`'s tests depending
    on each other's order, `live_b130_test` leaving a task when it fails, `walks_test` with no guard
    that any walk was found, a fixed 300 ms wait in `openTheDestinations`, unchecked `ssh-keygen` and
    `ssh-add`.

**Documentation and lints:** about twenty doc comments now head the member after the one they
describe, where new code went in between; about seventy new public members have none
(`public_member_api_docs`); three `discarded_futures`. `strict-casts`, `strict-inference` and
`strict-raw-types` find nothing in `lib`, so they go on.

**The workflows:** five `actions/checkout` without `persist-credentials: false`.

**Which findings carry a test,** under the shared rule that a test guards what can do harm: the
harm each prevents is named in its part, [F125](README.md#f125), [F126](README.md#f126) or
[F127](README.md#f127). Without a test, as they name none: 11, 15-17, 19-22, 26, the documentation
and the colours. Of the tests that cannot fail (28), those that guard a harm are repaired and the
others deleted.

**Decided by the operator:**

- **`porelo/frontend.json` keeps the top-level keys it does not know** when the interface writes it;
  that disturbs no reader and stops entries being lost ([F125](README.md#f125)).
- **Colours are held to the tokens too:** the about forty literals in `theme.dart` and
  `terminal_look.dart` move into `tokens.dart`, the rule goes into `AGENTS.md` beside the one for
  sizes; no test holds them there, since a colour only reads wrong ([F126](README.md#f126)).
- **The walks are translated into US English:** `walk_texts.dart` holds German sentences, against
  "everything written is US English" ([F126](README.md#f126)).

**Where a skill and a rule here disagree,** to be named in `doc/decisions.md` with the cleanup: `dart-build-cli-app` asks for
`package:test_process` and `test_descriptor` and a thin `bin/`; the suite drives its processes with
stand-in scripts in temporary folders, and `tool/contract.dart` stays dependency-free.

## Acceptance

- **Every file in the scope was read against all sixteen skills**, and the versions and SHA-256s
  used are in this issue.
- **Each finding is fixed, with a test seen to fail without its fix where it prevents a harm, or
  declined here with its reason**; a skill that contradicts a measured rule is named in
  `doc/decisions.md`.
- **`dart analyze` is clean and the whole suite is green** on the commit handed over.

## To be checked

- That the skills loaded in the harness are the reviewed packages from `agent-skills` at the
  versions above. The `dart-flutter` plugin installed here may differ, and it does not carry
  `dart-use-path-package` or `dart-write-documentation`.
