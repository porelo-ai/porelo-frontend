# Building it and working on it

The interface is Flutter, on Linux. It talks to Porelo's daemon over one unix socket, and to a
machine elsewhere over an ssh forward of that socket. It never runs the `porelo` command line and
parses it: that would be a second implementation of every refusal the product makes.

Where to read on:
- [The backend API](doc/Backend-API.md): the protocol, connecting, and staying compatible with a
  backend older than this build.
- [What the contract does not yet cover](doc/Contract-Gaps.md): what has no backend method yet.
- [Design](doc/design.md): what the interface is built out of.
- [Requirements](issues/README.md): what is still to do, in order.
- [AGENTS.md](AGENTS.md): the rules for working here, and what was measured.
- [A guided walk](doc/guided-walk.md): in a development build, an agent leads a person through the
  interface beside its window.

## Build and test

Needs the Flutter SDK and the Linux desktop toolchain: `clang`, `cmake`, `ninja`, `pkg-config`,
`libgtk-3-dev`. `flutter doctor -v` says whether they are all there. The suite needs no daemon, no
podman and no JDK: it runs against a mock.

```bash
flutter pub get
dart run build_runner build     # regenerates the tests from test/features/*.feature
dart analyze                    # must stay at "No issues found!"
flutter test
flutter build linux --release   # the bundle is in build/linux/x64/release/bundle
```

`dart analyze`, never `flutter analyze`: the latter can rewrite `analysis_options.yaml`. Run
`build_runner` after editing a `.feature` file; the generated test beside it is committed, and CI
fails on a difference.

With a real `porelod` running, one more suite checks that this client agrees with it:

```bash
PORELO_SOCKET=$XDG_RUNTIME_DIR/porelo/porelod.sock flutter test test/client/live_daemon_test.dart
```

One of its tests enrolls a device in the vault and revokes it again, so it also needs
`PORELO_VAULT_TEST=1`, and belongs only on a machine whose vault is a test's own.

To see what a running backend offers: `dart tool/contract.dart`.

## Seeing it run, with no backend at all

The mock daemon is a real unix socket speaking real varlink. In two terminals:

```bash
dart tool/mock_daemon.dart       # leave it running
flutter run -d linux
```

It appears as the machine **mock**. Pressing RETURN in the mock's terminal adds a task, so live
updates can be watched arriving; `b` blocks a connection, and `x` lets that question run out.
`PORELO_SOCKET` moves where the interface looks for it.

Situations no real daemon can be asked for on demand:

| Command | What it serves |
|---|---|
| `dart tool/mock_daemon.dart empty` | a machine nothing has ever run on |
| `dart tool/mock_daemon.dart no-watch` | a backend too old for `Watch`, so nothing arrives by itself |
| `dart tool/mock_daemon.dart holds-work` | work that refuses to be removed because it holds unpushed commits |
| `dart tool/mock_daemon.dart nothing-knows` | work nothing can say anything about |
| `dart tool/mock_daemon.dart newer-outcome` | an `Outcome` added after this build shipped |
| `dart tool/mock_daemon.dart newer-interface` | a backend serving `Tasks2` beside `Tasks1` |
| `dart tool/mock_daemon.dart failing-start` | a launch that prints for a while and then fails |
| `dart tool/mock_daemon.dart out-of-time` | an unattended run killed by its own time limit |
| `dart tool/mock_daemon.dart no-agent` | a run asked for when nothing is installed to run it |

A second mock, to watch several machines at once, is added in the interface with *Watch another
machine…*:

```bash
dart tool/mock_daemon.dart work /tmp/porelo-elsewhere.sock
```

**A second launch** does not open a second window: it asks the one running to come forward, and
leaves. Under `flutter run` that exit is reported as *Error connecting to the service protocol*;
nothing went wrong.

## Packages

```bash
tool/package.sh                 # writes build/packages/*.deb and *.rpm
```

Needs [nfpm](https://github.com/goreleaser/nfpm/releases) on `PATH`, `dpkg-dev` and `binutils`.
Dependencies are derived from the binary: `dpkg-shlibdeps` for Debian, the ELF's sonames for rpm.
The build machine sets the floor, since the bundle links the system's GTK, so build on the oldest
distribution to be supported. `amd64` only: Flutter has no cross-compile for Linux desktop.

Every build of `main` publishes `<version>~snapshot.<run number>` to the `snapshots` distribution,
`pubspec.yaml` saying `<version>-SNAPSHOT`, and each supersedes the one before, so `apt upgrade` and
`dnf upgrade` take it. A tag `v<version>` builds the release into the `releases` distribution, only
where `pubspec.yaml` says exactly that version, and a release published once is never replaced.

## On a build server

```bash
flutter test --machine > build/test-results.json
dart tool/test_report.dart                    # build/test-report.html
tojunit < build/test-results.json > build/test-results.xml
```

`tojunit` comes from `junitreport` (`dart pub global activate junitreport`). The HTML report is one
self-contained file, and `dart tool/test_report.dart` exits non-zero when anything failed, so it can
gate a build on its own. Each feature file's `Feature` line says in one sentence what it tests, and
becomes the report's group.
