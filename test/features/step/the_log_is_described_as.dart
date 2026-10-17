import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the log {'events.jsonl'} is described as {'what the firewall blocked'}
Future<void> theLogIsDescribedAs(WidgetTester tester, String log, String what) async {
  final tile = tester.widget<ListTile>(find.ancestor(of: find.text(log), matching: find.byType(ListTile)));
  expect(find.descendant(of: find.byWidget(tile), matching: find.text(what)), findsOneWidget);
}
