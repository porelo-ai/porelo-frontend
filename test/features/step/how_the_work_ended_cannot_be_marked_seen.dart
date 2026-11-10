import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/expand_list_rows.dart';

/// Usage: how the work ended cannot be marked seen
Future<void> howTheWorkEndedCannotBeMarkedSeen(WidgetTester tester) async {
  final open = find.byKey(const Key('open-attention'));
  await expandListRows(tester, within: open);
  expect(find.descendant(of: open, matching: find.byKey(const Key('ended-read-log'))), findsOneWidget);
  expect(find.descendant(of: open, matching: find.byKey(const Key('ended-put-away'))), findsNothing);
}
