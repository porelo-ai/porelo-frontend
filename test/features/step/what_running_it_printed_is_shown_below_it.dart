import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: what running it printed is shown below it {'porelo installed'}
Future<void> whatRunningItPrintedIsShownBelowIt(WidgetTester tester, String line) async {
  final printed = tester.widget<SelectableText>(find.byKey(const Key('setup-output'))).data!;
  expect(printed, contains(line));
  expect(printed, isNot(contains('useradd --create-home')), reason: 'what was shown came again');
}
