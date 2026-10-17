import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/remote.dart';

/// Usage: the machine lists that message as refused by a person
Future<void> theMachineListsThatMessageAsRefusedByAPerson(WidgetTester tester) async {
  final listed = await onTheTestMachine('PATH="\$HOME/.local/bin:\$PATH"; porelo talk held porelo-e2e-talk-e2e-talk');
  expect(listed, contains(theHeldMessage));
  expect(listed.split('\n').firstWhere((line) => line.contains(theHeldMessage!)), contains('refused'));
  // The dialog closed itself once decided; closed here only where it stayed.
  if (find.byKey(const Key('held-message-close')).evaluate().isNotEmpty) {
    await tester.tap(find.byKey(const Key('held-message-close')));
    await pumpFor(tester);
  }
}
