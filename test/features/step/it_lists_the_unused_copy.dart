import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: it lists the unused copy {'/usr/libexec/porelo/agents/an-agent'}
Future<void> itListsTheUnusedCopy(WidgetTester tester, String path) async {
  // A packaged agent hidden by a hand-placed copy was found on a real machine the day this
  // arrived. Nothing else in the product surfaces it, so the list is the whole of the answer.
  expect(find.byKey(const Key('agent-shadowed')), findsWidgets);
  expect(find.text(path), findsOneWidget);
}
