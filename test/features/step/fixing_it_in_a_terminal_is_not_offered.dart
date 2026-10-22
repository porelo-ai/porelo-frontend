import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: fixing it in a terminal is not offered
Future<void> fixingItInATerminalIsNotOffered(WidgetTester tester) async {
  expect(find.byKey(const Key('start-fix-in-a-terminal')), findsNothing);
}
