import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/panes.dart';

import '../../support/expand_list_rows.dart';

/// Usage: it says {'the attempt that was refused is gone'}
Future<void> itSays(WidgetTester tester, String words) async {
  if (find.textContaining(words).evaluate().isEmpty) {
    await expandListRows(tester, within: find.byKey(const Key('open-attention')));
  }
  // A work's page builds only the lines in view: what stands further down is scrolled to, as a person does.
  final page = find.descendant(of: find.byType(WorkDetail), matching: find.byType(Scrollable));
  if (find.textContaining(words).evaluate().isEmpty && page.evaluate().isNotEmpty) {
    await tester.scrollUntilVisible(find.textContaining(words), 200, scrollable: page.first, maxScrolls: 20);
  }
  expect(find.textContaining(words), findsWidgets);
}
