import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';
import '../../support/menu_entries.dart';

/// Usage: I begin enrolling this device
Future<void> iBeginEnrollingThisDevice(WidgetTester tester) async {
  // From the machine's menu: enrolling is not a task the title bar should carry.
  await tester.tap(find.byKey(const Key('machine-menu')).first);
  await World.settle(tester);
  await chooseMenuEntry(tester, menuEntry('Enroll this device on this machine'));
  await World.settle(tester);
}
