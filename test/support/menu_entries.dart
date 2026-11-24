import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The entry of an open command menu that reads [label], wherever it stands in the menu that is open now.
Finder menuEntry(String label) => find.ancestor(of: find.text(label), matching: find.byType(MenuItemButton));

/// The entry of an open command menu whose words contain [words].
Finder menuEntryContaining(String words) =>
    find.ancestor(of: find.textContaining(words), matching: find.byType(MenuItemButton));

/// The entry [found] of the open command menu, with the submenu that holds it opened first, as a person would.
///
/// Each submenu of the open menu is scrolled to and opened in turn until the entry shows, keyed or not; when none
/// holds it, no submenu is left open and the finder finds nothing.
Future<Finder> revealMenuEntry(WidgetTester tester, Finder found) async {
  if (found.evaluate().isNotEmpty) return found;
  final submenus = find.byType(SubmenuButton);
  // Counted again each time: a submenu inside an opened one is tried in its turn.
  for (var index = 0; index < submenus.evaluate().length; index++) {
    final submenu = submenus.at(index);
    await tester.ensureVisible(submenu);
    await _settle(tester);
    await tester.tap(submenu);
    await _settle(tester);
    if (found.evaluate().isNotEmpty) return found;
  }
  await _closeSubmenus(tester);
  return found;
}

/// Closes every submenu of the open menu, leaving the menu itself open.
Future<void> _closeSubmenus(WidgetTester tester) async {
  for (final element in find.byType(SubmenuButton).evaluate().toList().reversed) {
    // Each submenu's own anchor, whether or not the menu gave it a controller.
    final anchor = find.descendant(
      of: find.byElementPredicate((each) => each == element),
      matching: find.byType(MenuAnchor),
    );
    final controller = anchor.evaluate().isEmpty ? null : (anchor.evaluate().first.widget as MenuAnchor).controller;
    if (controller != null && controller.isOpen) controller.close();
  }
  await _settle(tester);
}

/// The entry of the open menu that reads [label], its submenu opened first.
Future<Finder> revealMenuEntryLabeled(WidgetTester tester, String label) => revealMenuEntry(tester, menuEntry(label));

/// Whether the entry [found] can be chosen now.
bool menuEntryEnabled(WidgetTester tester, Finder found) => tester.widget<MenuItemButton>(found).enabled;

/// Opens the submenu holding [found], then chooses it.
Future<void> chooseMenuEntry(WidgetTester tester, Finder found) async {
  final entry = await revealMenuEntry(tester, found);
  await tester.ensureVisible(entry.last);
  await tester.pump();
  await tester.tap(entry.last);
  await _settle(tester);
}

/// Lets a menu open or close and a chosen entry run, without waiting on what keeps animating elsewhere.
Future<void> _settle(WidgetTester tester) async {
  for (var frame = 0; frame < 10; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
