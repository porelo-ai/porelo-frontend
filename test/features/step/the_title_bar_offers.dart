import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the title bar offers {'Find a command (Ctrl+K), Watch another machine…, Options, About Porelo'}
Future<void> theTitleBarOffers(WidgetTester tester, String actions) async {
  final bar = find.byType(AppBar);
  final buttons = tester
      .widgetList<IconButton>(find.descendant(of: bar, matching: find.byType(IconButton)))
      .map((button) => button.tooltip ?? '')
      .where((tooltip) => tooltip.isNotEmpty && tooltip != 'Open navigation menu');
  final menus = tester
      .widgetList<PopupMenuButton<String>>(find.descendant(of: bar, matching: find.byType(PopupMenuButton<String>)))
      .map((menu) => menu.tooltip ?? '');
  expect(<String>{...buttons, ...menus}, actions.split(', ').toSet());
}
