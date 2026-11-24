import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';
import '../../support/menu_entries.dart';
import 'the_stores_lock_says.dart';

/// Usage: enrolling is offered in the machine's menu
Future<void> enrollingIsOfferedInTheMachinesMenu(WidgetTester tester) async {
  // The menu on top of the machine's own page, where its lock is too.
  await toTheLock(tester);
  await tester.tap(find.byKey(const Key('machine-menu')).first);
  await World.settle(tester);
  // Opened from its submenu first, as a person would.
  final item = await revealMenuEntryLabeled(tester, 'Enroll this device on this machine');
  expect(item, findsOneWidget);
  expect(tester.widget<MenuItemButton>(item).enabled, isTrue);
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await World.settle(tester);
}
