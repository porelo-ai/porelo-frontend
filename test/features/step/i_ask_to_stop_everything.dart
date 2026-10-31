import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';

/// Usage: I ask to stop everything
Future<void> iAskToStopEverything(WidgetTester tester) async {
  // One machine's stop is in the menu on top of its own page, at its foot.
  await toTheMachinesPage(tester, World.machines.current.name);
  await tester.tap(find.byKey(const Key('machine-menu')));
  await World.settle(tester);
  final stop = find.byKey(const ValueKey<String>('machine.panic')).last;
  await tester.ensureVisible(stop);
  await tester.pump();
  await tester.tap(stop);
  await World.settle(tester);
}
