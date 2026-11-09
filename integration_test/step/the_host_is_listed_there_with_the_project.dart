import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/rehearsal.dart';

/// Usage: the host is listed there with the project
Future<void> theHostIsListedThereWithTheProject(WidgetTester tester) async {
  final row = find.byKey(ValueKey('organization-machine ${Rehearsal.hostName}'));
  await pumpUntil(tester, () => row.evaluate().isNotEmpty, what: 'the row of ${Rehearsal.hostName}');
  expect(theWordsUnder(tester, row.first), contains(Rehearsal.project));
}
