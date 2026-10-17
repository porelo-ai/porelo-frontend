import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: leaving it running is the default
Future<void> leavingItRunningIsTheDefault(WidgetTester tester) async {
  // A stray Return or a mis-aimed click has to carry nothing. The button that acts is the plainer
  // of the two and never holds focus.
  final leave = tester.widget<FilledButton>(find.byKey(const Key('leave-it-running')));
  expect(leave.autofocus, isTrue);
  expect(find.byKey(const Key('stop-it-all')), findsOneWidget);
  expect(tester.widget<TextButton>(find.byKey(const Key('stop-it-all'))).autofocus, isFalse);
}
