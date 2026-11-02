import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: no agent is picked yet
Future<void> noAgentIsPickedYet(WidgetTester tester) async {
  expect(tester.widget<DropdownButtonFormField<String>>(find.byKey(const Key('start-agent'))).initialValue, isNull);
}
