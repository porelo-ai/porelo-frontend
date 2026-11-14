// Linux only: it runs the build's script in Bash, with a stand-in for `git`.
@Tags(<String>['linux'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Holds tool/planner_pin.sh, the build step that says when the planning screen's pin is not porelo-planner's main,
/// run here against a stand-in `git` that answers `ls-remote` as the forge would.
void main() {
  late Directory scratch;
  late Directory bin;
  late File pubspec;

  const url = 'https://github.com/porelo-ai/porelo-planner.git';
  const pinned = '6bdad25f08591dfe44d6a9c338a92e291003e446';
  const newer = 'fa6bbe3c38b10864027aea3bb790a8ff50c2b673';

  setUp(() {
    scratch = Directory.systemTemp.createTempSync('planner-pin-');
    bin = Directory('${scratch.path}/bin')..createSync();
    pubspec = File('${scratch.path}/pubspec.yaml')
      ..writeAsStringSync('''
dependencies:
    flutter:
        sdk: flutter
    porelo_planning:
        git:
            url: $url
            ref: $pinned
            path: screen
    path: ^1.9.1
''');
  });

  tearDown(() => scratch.deleteSync(recursive: true));

  /// A `git` whose `ls-remote` of [url] answers [main], or fails when it is null.
  void forgeSays(String? main) {
    final git = File('${bin.path}/git')
      ..writeAsStringSync('''
#!/usr/bin/env bash
[ "\$1 \$2 \$3" = "ls-remote $url refs/heads/main" ] || exit 2
${main == null ? 'exit 128' : 'printf "%s\\trefs/heads/main\\n" $main'}
''');
    Process.runSync('chmod', ['+x', git.path]);
  }

  ProcessResult run() => Process.runSync(
    'bash',
    ['tool/planner_pin.sh', pubspec.path],
    environment: {'PATH': '${bin.path}:${Platform.environment['PATH']}'},
  );

  // Harm: a planner fix on main waits unseen behind the window's pin until somebody finds it live.
  test('a pin behind main is a warning naming both, and fails nothing', () {
    forgeSays(newer);
    final ran = run();
    expect(ran.exitCode, 0);
    expect(ran.stdout, contains('::warning::'));
    expect(ran.stdout, contains(pinned));
    expect(ran.stdout, contains(newer));
  });

  // Harm: a warning on every build, also where the pin is main, so nobody reads it any more.
  test('a pin at main says nothing', () {
    forgeSays(pinned);
    final ran = run();
    expect(ran.exitCode, 0);
    expect(ran.stdout, isEmpty);
  });

  // Harm: a forge that cannot be read fails the build, or passes as if the pin were current.
  test('a main that cannot be read is a warning that the pin is unchecked', () {
    forgeSays(null);
    final ran = run();
    expect(ran.exitCode, 0);
    expect(ran.stdout, contains('unchecked'));
  });
}
