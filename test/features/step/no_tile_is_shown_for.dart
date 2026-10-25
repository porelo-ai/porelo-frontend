import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../../support/expand_list_rows.dart';

/// Usage: no tile is shown for {'porelo-billing-shell'}
Future<void> noTileIsShownFor(WidgetTester tester, String work) async {
  await expandListRows(tester, within: find.byKey(const Key('open-attention')));
  expect(tileFor(work), findsNothing);
}
