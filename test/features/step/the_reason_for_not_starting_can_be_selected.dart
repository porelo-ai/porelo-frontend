import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the reason for not starting can be selected
Future<void> theReasonForNotStartingCanBeSelected(WidgetTester tester) async {
  // It ends with the command that fixes it, which is copied to a terminal.
  expect(
    find.byWidgetPredicate((widget) => widget is SelectableText && widget.key == const Key('not-ready-detail')),
    findsOneWidget,
  );
}
