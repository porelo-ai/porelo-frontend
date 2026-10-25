import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/expand_list_rows.dart';

/// Usage: it says {'the attempt that was refused is gone'}
Future<void> itSays(WidgetTester tester, String words) async {
  if (find.textContaining(words).evaluate().isEmpty) {
    await expandListRows(tester, within: find.byKey(const Key('open-attention')));
  }
  expect(find.textContaining(words), findsWidgets);
}
