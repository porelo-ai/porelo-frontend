import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the machine's bar is shown {false}
Future<void> theMachinesBarIsShown(WidgetTester tester, bool shown) async {
  // The machine's own heading and menu, which stand on its page and never on a project's.
  expect(find.byKey(const Key('machine-menu')).evaluate().isNotEmpty, shown);
}
