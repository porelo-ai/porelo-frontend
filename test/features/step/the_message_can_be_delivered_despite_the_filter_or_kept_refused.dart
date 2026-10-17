import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the message can be delivered despite the filter or kept refused
Future<void> theMessageCanBeDeliveredDespiteTheFilterOrKeptRefused(WidgetTester tester) async {
  expect(
    find.descendant(of: find.byKey(const Key('release-message')), matching: find.text('Deliver it despite the filter')),
    findsOneWidget,
  );
  expect(
    find.descendant(of: find.byKey(const Key('refuse-message')), matching: find.text('Keep it refused')),
    findsOneWidget,
  );
  expect(find.text('Release it'), findsNothing, reason: 'a refused message is never said to be released');
}
