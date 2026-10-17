import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: it shows {'pub.dev'} granted by {'set dart-packages'}
Future<void> itShowsGrantedBy(WidgetTester tester, String host, String origin) async {
  // The first grant wins, so which source a host came from is the answer — and it is why the
  // order it arrives in is never sorted away.
  final row = find.ancestor(of: find.text(host), matching: find.byType(ListTile));
  expect(find.descendant(of: row.first, matching: find.text(origin)), findsOneWidget);
}
