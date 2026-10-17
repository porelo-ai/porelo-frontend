import 'package:flutter_test/flutter_test.dart';

import '../support/remote.dart';

/// Usage: the task {'porelo-e2e-talk-e2e-talk'} and the project {'e2e-talk'} are removed again
Future<void> theTaskAndTheProjectAreRemovedAgain(WidgetTester tester, String task, String project) async {
  await onTheTestMachine('''
PATH="\$HOME/.local/bin:\$PATH"
porelo task stop "$task" >/dev/null 2>&1 || true
porelo task remove "$task" >/dev/null 2>&1 || true
porelo project unfollow --force "$project" >/dev/null 2>&1 || true
rm -rf "\$HOME/$project" "\$HOME/$project-backend.git"
''');
  final left = await onTheTestMachine('PATH="\$HOME/.local/bin:\$PATH"; porelo task list; porelo project list');
  expect(left, isNot(contains(task)));
}
