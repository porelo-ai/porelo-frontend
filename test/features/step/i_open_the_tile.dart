import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I open the tile {'porelo-billing-shell'}
Future<void> iOpenTheTile(WidgetTester tester, String work) async {
  await tester.tap(find.byKey(ValueKey<String>('tile-fold $work')));
  await World.settle(tester);
}
