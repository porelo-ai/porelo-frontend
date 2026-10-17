import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the newest line {'line 400 of a log written hard'} is in view
Future<void> theNewestLineIsInView(WidgetTester tester, String line) async {
  final shown = find.textContaining(line, findRichText: true);
  expect(shown, findsOneWidget);
  final scroll = tester.state<ScrollableState>(find.ancestor(of: shown, matching: find.byType(Scrollable)).first);
  expect(scroll.position.pixels, scroll.position.maxScrollExtent);
}
