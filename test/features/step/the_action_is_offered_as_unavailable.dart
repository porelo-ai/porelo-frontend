import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the action {'Rename it'} is offered as unavailable
Future<void> theActionIsOfferedAsUnavailable(WidgetTester tester, String action) async {
  final tile = tester.widget<ListTile>(find.widgetWithText(ListTile, action));
  expect(tile.enabled, isFalse, reason: '$action should not be runnable now');
  expect((tile.subtitle! as Text).data, contains('Unavailable'));
}
