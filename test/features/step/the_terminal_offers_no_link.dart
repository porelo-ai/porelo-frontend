import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the terminal offers no link
Future<void> theTerminalOffersNoLink(WidgetTester tester) async {
  expect(
    find.byWidgetPredicate(
      (each) => each.key is ValueKey<String> && (each.key! as ValueKey<String>).value.startsWith('terminal-link '),
    ),
    findsNothing,
  );
}
