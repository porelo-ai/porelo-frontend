import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../../support/expand_list_rows.dart';

/// Usage: the first tile is {'porelo-billing-shell'}
///
/// Under *Needs you*, the first row a piece of work has there; elsewhere, the first piece of work.
Future<void> theFirstTileIs(WidgetTester tester, String work) async {
  final open = find.byKey(const Key('open-attention'));
  await expandListRows(tester, within: open);
  final rows = (open.evaluate().isEmpty ? workRows() : find.descendant(of: open, matching: causeRows()))
      .evaluate()
      .toList();
  expect(rows, isNotEmpty, reason: 'no work is on screen');
  expect('${rows.first.widget.key}', contains(work));
}
