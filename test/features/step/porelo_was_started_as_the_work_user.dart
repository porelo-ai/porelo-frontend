import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: Porelo was started as the work user
Future<void> poreloWasStartedAsTheWorkUser(WidgetTester tester) async {
  // Started, then its hooks registered, then asked — in that order, all as the work user.
  final ran = World.setup.asUserRan;
  final started = ran.indexOf('systemctl --user enable --now porelod');
  final registered = ran.indexOf('porelo setup');
  final asked = ran.indexOf('porelo doctor');
  expect(started, isNonNegative, reason: 'Porelo was not started');
  expect(registered, greaterThan(started), reason: 'porelo setup did not run after the start');
  expect(asked, greaterThan(registered), reason: 'porelo doctor was asked before porelo setup');
  expect(World.setup.asRootRan.where((script) => script.contains('systemctl --user') || script.contains('porelo setup')), isEmpty,
      reason: "root started another user's service");
}
