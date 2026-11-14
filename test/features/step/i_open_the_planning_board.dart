import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I open the planning board
Future<void> iOpenThePlanningBoard(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('rail planning')));
  await World.settle(tester);
  // The page's explanation stands open the first time; the board is worked once it is read and closed.
  final fold = find.byKey(const ValueKey<String>('explanation-fold planning'));
  if (fold.evaluate().isNotEmpty) {
    await tester.tap(fold);
    await World.settle(tester);
  }
}
