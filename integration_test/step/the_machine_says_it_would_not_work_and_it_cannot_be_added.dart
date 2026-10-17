import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/remote.dart';

/// Usage: the machine says it would not work, and it cannot be added
Future<void> theMachineSaysItWouldNotWorkAndItCannotBeAdded(WidgetTester tester) async {
  debugPrint('the check said: $theCheckSaid');
  expect(
    find.text('This would not work as it is.'),
    findsOneWidget,
    reason: 'the real dry run let through what a declare would refuse',
  );
  expect(theCheckSaid, isNotEmpty, reason: 'the refusal says nothing a person could act on');
  expect(
    tester.widget<ButtonStyleButton>(find.byKey(const Key('connection-add'))).onPressed,
    isNull,
    reason: 'Add it is pressable over a refusal',
  );
}
