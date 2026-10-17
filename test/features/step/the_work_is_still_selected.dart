import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: the work {'porelo-checkout-shell'} is still selected
Future<void> theWorkIsStillSelected(WidgetTester tester, String work) async {
  await toTheTile(tester, work);
  expect(find.ancestor(of: find.text(work), matching: find.byKey(const Key('selected-row'))), findsOneWidget);
}
