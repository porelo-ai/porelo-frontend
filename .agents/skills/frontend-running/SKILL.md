---
name: frontend-running
description: porelo-frontend: running the interface. Use when starting or debugging the frontend.
---

# frontend-running

### Running it

    dart tool/mock_daemon.dart                  # prints a socket and a situation to choose
    PORELO_SOCKET=<that socket> flutter run -d linux
    dart run build_runner build && dart format test/features integration_test   # after editing a feature
    dart analyze                                # stays at "No issues found!"
    flutter test                                # the whole suite
    flutter test --tags documents               # a change to documents or issues alone
    tool/e2e.sh                                 # the integration leg, against PORELO_E2E_HOST
    tool/rehearse_window.sh check --vm …        # a move rehearsed in the window, in a VM, against a rented host
    tool/walk_idea.sh check --vm …              # a real idea walked to Finished in the window, in a VM, against its porelo
    flutter build linux --release && tool/package.sh

- **`dart analyze`, never `flutter analyze`**, which rewrites `analysis_options.yaml` with an exclude
  block that silences findings.
- **Dart is formatted with plain `dart format lib test integration_test tool`**, by the repository's own
  settings: never with `-l`, and never `packages/` (`packages/xterm` is not kept formatted). After
  `build_runner`, `dart format test/features integration_test` comes before the generated tests are compared.
- **A new worktree runs `flutter pub get` and `dart pub get --directory=packages/porelo_host` before its
  first `dart format` or `dart analyze`**: without resolved packages the include of `analysis_options.yaml`
  fails, `dart format` rewraps about 1100 files at 80 columns and analyze reports thousands of errors.
- **The mock daemon is started with a deadline** (`timeout 20 dart tool/mock_daemon.dart`): it reads
  keys, a closed standard input is no key, and it runs on otherwise.
- **The Linux desktop toolchain is `clang`, `cmake`, `ninja`, `pkg-config`, `libgtk-3-dev` and
  `libsecret-1-dev`**; `flutter doctor -v` says what is missing.
- **Before a commit, its message passes the Build's check**: `java -cp "$(cat build/jdk-cp.txt)"
  org.fuin.porelo.release.Main check-commits origin/main..HEAD`, with `build/jdk-cp.txt` from a current Maven build.
- **A whole suite runs with `TMPDIR` on a disk with room**: its `dart_test.*` folders and logs grow large, and a
  `/tmp` held in memory fills.
- **Skills it uses:** `dart-add-unit-test`, `dart-build-cli-app`, `dart-collect-coverage`,
  `dart-generate-test-mocks`, `dart-resolve-package-conflicts`, `dart-run-static-analysis`,
  `dart-use-path-package`, `dart-use-pattern-matching`, `dart-use-primary-constructors`,
  `dart-write-documentation`, `flutter-add-integration-test`, `flutter-add-widget-test`,
  `flutter-apply-architecture-best-practices`, `flutter-build-responsive-layout`,
  `flutter-fix-layout-issues`, `flutter-implement-json-serialization`.
