import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import 'the_test_machine_has_a_project_with_a_conversation.dart';

import '../support/remote.dart';

/// Usage: the project {'e2e-mx'} and its task are removed again
Future<void> theProjectAndItsTaskAreRemovedAgain(WidgetTester tester, String name) async {
  if (noConversationHere != null) return;
  // Done with the login, as a person is: the dialog goes, and the forward it held with it.
  final done = find.byKey(const Key('messages-close'));
  if (done.evaluate().isNotEmpty) {
    await tester.tap(done);
    await pumpFor(tester);
  }
  // The account's homeserver stays, as Porelo left it enabled for the account; its accounts with it.
  final left = await onTheTestMachine('''
PATH="\$HOME/.local/bin:\$PATH"
set -e
porelo task stop porelo-$name-write >/dev/null
porelo task remove --force porelo-$name-write >/dev/null
porelo project unfollow --force $name >/dev/null
rm -rf "\$HOME/$name"
porelo task list
porelo project list
''');
  expect(left, isNot(contains('porelo-$name-')));
  expect(left, isNot(contains(RegExp('\\b${RegExp.escape(name)}\\b'))), reason: '$name is still followed');
}
