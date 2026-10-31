import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../../support/expand_list_rows.dart';

/// Usage: the first tile is {'porelo-billing-shell'}
Future<void> theFirstTileIs(WidgetTester tester, String work) async {
  await expandListRows(tester, within: find.byKey(const Key('open-attention')));
  final rows = workRows().evaluate().toList();
  expect(rows, isNotEmpty, reason: 'no work is on screen');
  expect('${rows.first.widget.key}', contains(work));
}
