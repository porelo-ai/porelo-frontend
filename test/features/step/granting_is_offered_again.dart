import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: granting {'jira'} is offered again
Future<void> grantingIsOfferedAgain(WidgetTester tester, String name) async {
  expect(
    find.descendant(of: find.byKey(ValueKey<String>('grant $name')), matching: find.text('Grant it again')),
    findsOneWidget,
  );
}
