import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I choose to refresh automatically {'every 30 seconds'}
Future<void> iChooseToRefreshAutomatically(WidgetTester tester, String how) async {
  await tester.tap(find.byTooltip('Options'));
  await World.settle(tester);
  await tester.tap(find.widgetWithText(CheckedPopupMenuItem<String>, 'Refresh automatically: $how'));
  await World.settle(tester);
}
