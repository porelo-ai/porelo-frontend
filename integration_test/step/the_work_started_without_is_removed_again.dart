import 'package:flutter_test/flutter_test.dart';

import '../support/remote.dart';
import 'work_on_the_test_machine_was_started_without_a_grant_of.dart';

/// Usage: the work started without {'e2e-needed'} is removed again
Future<void> theWorkStartedWithoutIsRemovedAgain(WidgetTester tester, String entry) async {
  await onTheTestMachine('''
PATH="\$HOME/.local/bin:\$PATH"
set -e
porelo task remove --force porelo-$refusedProject-auth >/dev/null
porelo project unfollow --force $refusedProject >/dev/null
rm -rf "\$HOME/$refusedProject"
rm -f "\${XDG_DATA_HOME:-\$HOME/.local/share}/porelo/destinations/e2e-api.yaml"
''');
  final left = await onTheTestMachine('PATH="\$HOME/.local/bin:\$PATH"; porelo task list');
  expect(left, isNot(contains('porelo-$refusedProject-auth')));
}
