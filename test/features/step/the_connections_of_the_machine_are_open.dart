import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the connections of the machine are open
Future<void> theConnectionsOfTheMachineAreOpen(WidgetTester tester) async {
  expect(find.byKey(const Key('connections-menu')), findsOneWidget);
}
