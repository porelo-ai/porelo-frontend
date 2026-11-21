---
name: frontend-tests
description: porelo-frontend test rules. Use when writing or running frontend tests.
---

# frontend-tests

### Tests

- **Features are Gherkin files generated into widget tests by `bdd_widget_test`, and the generated
  tests are committed.** A `Feature` line is one short sentence, step wording is an API reused as
  is, and an apostrophe or a `$` in a step's text breaks the generated Dart.
- **No requirement id appears in the code or the documents**: `porelo-release check-citations .` enforces it, and
  `check-doc-site doc mkdocs.yml` holds `doc/` to the site's navigation, and `check-readmes .` the
  `README.md` beside `pom.xml`; all three run on the host before every hand-over, and
  `shared-rules` once a day. A channel question number is kept out of the code by
  `test/features_named_test.dart`.
- **Three levels**: the frame against `FakeBackend` in `testWidgets`; the client against `MockDaemon`
  over a real unix socket in plain `test()`; `test/client/live_daemon_test.dart` against a real
  `porelod` when `PORELO_SOCKET` is set (and `PORELO_VAULT_TEST=1` for the vault round trip).
- **A socket never completes inside `testWidgets`**, which runs on a fake clock.
- **A build brief carries the checklist the readings keep finding**: absent, refused or unknown never shown
  as 0, empty or good; names and paths whole at 390 wide; the leaf's own machine or organization, never the
  current one; a mounted check after every await; where Back goes; a listener, subscription or connection
  left after dispose.
- **A stand-in acts on what it is told and is never canned**; the mock serves `pushes` for `Watch` and
  `Prompts` and `stream` for anything finite, driven by the test, never by the clock.
- **Widget tests run at 1280x800 on `tester.view` with `devicePixelRatio = 1`**; steps settle with
  `World.settle`, never `pumpAndSettle`, which never returns while a spinner shows.
- **A mock walk is used only for a major interface rebuild and targets the changed area**: the
  guided walk with stand-ins for `porelo-host`, the daemon or a transport, with their stops and
  failures, before it goes to a VM or a rented host. Smaller changes proceed to the real test without
  extending the mock or its stand-ins.
- **Before an operator test, try every dialog in the debug build as a newcomer.** Fix or file
  anything unclear before handing over the test.
- **A guide adds no daemon restart after package installation, because the package performs it.** If
  another reason requires a manual restart, use `systemctl --user daemon-reload && systemctl --user
  restart porelod`.
- **A unix socket path is limited to about 108 bytes.**
- **The integration leg runs headless under `xvfb-run` inside `dbus-run-session`**, the app with its
  own config and runtime directories; `./mvnw verify -Pe2e,leased` rents a machine through
  `porelo-machines` and sweeps it after a red run too.
- **A blank headless screenshot stops the GUI test until its display is understood.**
- **When explicitly requested, the interface may run on the operator’s desktop with the operator’s
  settings after the installed instance is closed.** Observe and point while the operator clicks and
  types.
