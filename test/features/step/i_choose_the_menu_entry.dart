import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I choose the menu entry {'Appearance: dark'}
///
/// A choice with alternatives is a submenu of the open menu: "Group: choice" opens Group, then taps choice.
Future<void> iChooseTheMenuEntry(WidgetTester tester, String entry) async {
  // A pointer alone, deliberately: no shortcut, no finder.
  final at = entry.indexOf(': ');
  if (at > 0 && find.widgetWithText(SubmenuButton, entry.substring(0, at)).evaluate().isNotEmpty) {
    await tester.tap(find.widgetWithText(SubmenuButton, entry.substring(0, at)));
    await World.settle(tester);
    await tester.tap(find.widgetWithText(MenuItemButton, entry.substring(at + 2)));
  } else {
    await tester.tap(find.text(entry).last);
  }
  await World.settle(tester);
}
