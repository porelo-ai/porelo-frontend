import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the menu offers {'Work in it by hand'} as unavailable because {'forwarded'}
Future<void> theMenuOffersAsUnavailableBecause(WidgetTester tester, String label, String reason) async {
  final item = find.ancestor(of: find.text(label), matching: find.byWidgetPredicate((w) => w is PopupMenuItem));
  expect(item, findsOneWidget);
  expect(tester.widget<PopupMenuItem<Object?>>(item).enabled, isFalse);
  expect(find.descendant(of: item, matching: find.textContaining(reason)), findsOneWidget);
}
