import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';

/// Usage: I ask to stop everything
Future<void> iAskToStopEverything(WidgetTester tester) async {
  // One machine's stop is an action on its own facts page.
  await toTheMachinesPage(tester, World.machines.current.name);
  final stop = find.byKey(const ValueKey<String>('machine.panic')).last;
  await tester.ensureVisible(stop);
  await tester.pump();
  await tester.tap(stop);
  await World.settle(tester);
}
