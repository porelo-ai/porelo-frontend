import 'package:flutter_test/flutter_test.dart';

import '../support/remote.dart';

/// Usage: the task {'porelo-e2e-talk_e2e-talk'} and the project {'e2e-talk'} are removed again
Future<void> theTaskAndTheProjectAreRemovedAgain(WidgetTester tester, String task, String project) async {
  await onTheTestMachine('''
PATH="\$HOME/.local/bin:\$PATH"
set -e
porelo task stop "$task" >/dev/null
porelo task remove --force "$task" >/dev/null
porelo project remove "$project" >/dev/null
${removingTheProjectFiles(project)}
''');
  final left = await onTheTestMachine('PATH="\$HOME/.local/bin:\$PATH"; porelo task list; porelo project list');
  expect(left, isNot(contains(task)));
  expect(left, isNot(contains(RegExp('\\b${RegExp.escape(project)}\\b'))), reason: '$project is still listed');
}
