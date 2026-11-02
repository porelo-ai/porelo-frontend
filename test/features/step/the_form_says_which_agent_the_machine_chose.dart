import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the form says which agent the machine chose
Future<void> theFormSaysWhichAgentTheMachineChose(WidgetTester tester) async {
  expect(find.byKey(const Key('start-machine-chose')), findsOneWidget);
}
