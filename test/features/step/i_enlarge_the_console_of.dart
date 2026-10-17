import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';

/// Usage: I enlarge the console of {'porelo-billing-shell'}
Future<void> iEnlargeTheConsoleOf(WidgetTester tester, String work) async {
  await toTheTile(tester, work);
  final enlarge = find.byKey(ValueKey<String>('tile-console-enlarge $work'));
  await tester.ensureVisible(enlarge);
  await tester.tap(enlarge);
  await World.settle(tester);
}
