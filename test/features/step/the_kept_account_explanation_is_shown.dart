import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the kept account explanation is shown
Future<void> theKeptAccountExplanationIsShown(WidgetTester tester) async {
  final result = find.byKey(const Key('member-removal-kept'));
  expect(result, findsOneWidget, reason: 'a retained account must not appear deleted');
  expect(
    tester.widget<SelectableText>(result).data,
    World.backend.retainedMessageAccounts.values.single,
    reason: 'only the transport explains why an account remains',
  );
  expect(find.byKey(const Key('messages-problem')), findsNothing);
}
