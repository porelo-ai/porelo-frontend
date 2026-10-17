import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/setup_run.dart';

/// What the wizard says `porelo doctor` refused, read from what it printed.
void main() {
  test('a passing doctor refuses nothing, DEGRADED or not', () {
    expect(SetupRun.refusedBy(ProcessResult(0, 0, 'configuration key   DEGRADED - none pinned', '')), isNull);
  });

  test('every marked line is kept with its advice, and nothing that passed', () {
    final found = SetupRun.refusedBy(ProcessResult(0, 69, '''
podman              MISSING - podman 4.9.3 is too old
                    -> run 'podman version'
rootless network    UNKNOWN - podman did not say
                    -> run 'podman info'
git                 2.43.0
configuration key   DEGRADED - none pinned
''', ''));
    expect(found, <String>[
      'podman              MISSING - podman 4.9.3 is too old',
      "                    -> run 'podman version'",
      'rootless network    UNKNOWN - podman did not say',
      "                    -> run 'podman info'",
    ]);
  });

  test('a refusal in words doctor did not mark is shown whole rather than lost', () {
    expect(SetupRun.refusedBy(ProcessResult(0, 70, '', 'porelo: cannot read the configuration\n')),
        <String>['porelo: cannot read the configuration']);
    expect(SetupRun.refusedBy(ProcessResult(0, 70, '', '')), <String>['porelo doctor ended with 70 and said nothing.']);
  });
}
