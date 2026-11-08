import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the list of work is sorted by {'Sorted by state'}
Future<void> theListOfWorkIsSortedBy(WidgetTester tester, String order) async {
  await tester.tap(find.byKey(const Key('work-list-sort')));
  await World.settle(tester);
  final selected = find.byKey(ValueKey<String>('work-list-sort $order'));
  expect(selected, findsOneWidget);
  expect(tester.widget<CheckedPopupMenuItem<String>>(selected).checked, isTrue);
  expect(find.descendant(of: selected, matching: find.text(order)), findsOneWidget);
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await World.settle(tester);
}
