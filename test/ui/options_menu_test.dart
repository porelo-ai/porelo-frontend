import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/step/i_open_the_command_finder.dart';
import '../features/support/world.dart';

/// The settings menu (the tune icon): one entry for each choice, its alternatives in a submenu, the one in force marked.
void main() {
  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await World.startBackend(World.work);
    await World.startApp(tester);
    await World.settle(tester);
    await World.tapInView(tester, 'options-menu');
  }

  Future<void> submenu(WidgetTester tester, String name) async {
    await tester.tap(find.widgetWithText(SubmenuButton, name));
    await World.settle(tester);
  }

  Finder item(String text) => find.widgetWithText(MenuItemButton, text);

  Finder marked(String text) => find.descendant(of: item(text), matching: find.byIcon(Icons.check));

  // Harm: the menu is a long list of near-identical lines, so the person cannot find the one setting wanted.
  testWidgets('each choice is one entry, and none of its alternatives is listed in the menu itself', (tester) async {
    await open(tester);
    for (final name in ['Appearance', 'Refresh automatically', 'Log level', 'Logs']) {
      expect(find.widgetWithText(SubmenuButton, name), findsOneWidget, reason: name);
    }
    expect(find.textContaining('Appearance:'), findsNothing);
    expect(find.textContaining('Refresh automatically:'), findsNothing);
    expect(find.textContaining('Log level:'), findsNothing);
  });

  // Harm: the person cannot tell which appearance is in force, or choosing one does nothing.
  testWidgets('Appearance offers light, dark and the desktop, marks the one in force and applies another', (
    tester,
  ) async {
    await open(tester);
    await submenu(tester, 'Appearance');
    expect(item('light'), findsOneWidget);
    expect(item('dark'), findsOneWidget);
    expect(item('follow the desktop'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(marked('follow the desktop'), findsOneWidget);

    await tester.tap(item('dark'));
    await World.settle(tester);
    expect(World.themeInUse(tester).brightness, Brightness.dark);

    await World.tapInView(tester, 'options-menu');
    await submenu(tester, 'Appearance');
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(marked('dark'), findsOneWidget);
  });

  // Harm: the person cannot tell how often the window refreshes, or the choice is not taken.
  testWidgets('Refresh automatically offers four intervals, marks the one in force and applies another', (
    tester,
  ) async {
    await open(tester);
    await submenu(tester, 'Refresh automatically');
    for (final words in ['off', 'every 30 seconds', 'every minute', 'every 5 minutes']) {
      expect(item(words), findsOneWidget, reason: words);
    }
    expect(find.byIcon(Icons.check), findsOneWidget);
    final before = World.settings.refreshSeconds;

    await tester.tap(item(before == 30 ? 'every minute' : 'every 30 seconds'));
    await World.settle(tester);
    expect(World.settings.refreshSeconds, before == 30 ? 60 : 30);

    await World.tapInView(tester, 'options-menu');
    await submenu(tester, 'Refresh automatically');
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(marked(before == 30 ? 'every minute' : 'every 30 seconds'), findsOneWidget);
  });

  // Harm: the person sees the level names with the group's words repeated, and cannot tell the usual one.
  testWidgets('Log level offers the four levels with INFO the usual, and choosing one takes it', (tester) async {
    await open(tester);
    await submenu(tester, 'Log level');
    for (final level in ['ERROR', 'WARN', 'INFO (the usual)', 'DEBUG']) {
      expect(item(level), findsOneWidget, reason: level);
    }
    expect(marked('INFO (the usual)'), findsOneWidget);

    await tester.tap(item('WARN'));
    await World.settle(tester);
    await World.tapInView(tester, 'options-menu');
    await submenu(tester, 'Log level');
    expect(marked('WARN'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  // Harm: the finder loses a command because the menu was shortened.
  testWidgets('the finder still finds each command by its whole words', (tester) async {
    await open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await World.settle(tester);
    for (final label in [
      'Appearance: dark',
      'Refresh automatically: every minute',
      'Log level: DEBUG',
      'Open the window’s log',
    ]) {
      await iOpenTheCommandFinder(tester);
      await tester.enterText(find.byKey(const Key('command-query')), label);
      await World.settle(tester);
      expect(
        find.descendant(of: find.byType(ListTile), matching: find.textContaining(label)),
        findsOneWidget,
        reason: 'the finder lists it by its whole words',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await World.settle(tester);
    }
  });

  // Harm: a person who does not use Ctrl+Plus cannot make the window larger or smaller, or cannot see its size now.
  testWidgets('the Zoom row makes the window smaller and larger and shows its size', (tester) async {
    await open(tester);
    expect(find.text('100 %'), findsOneWidget);

    await tester.tap(find.byKey(const Key('zoom-out')));
    await World.settle(tester);
    expect(World.settings.zoomPercent, 90);
    // Drawn at another size, the menu closes as on a resize; opened again, it says the size in force.
    if (find.byKey(const Key('zoom-reset')).evaluate().isEmpty) await World.tapInView(tester, 'options-menu');
    expect(find.text('90 %'), findsOneWidget);

    await tester.tap(find.byKey(const Key('zoom-in')));
    await World.settle(tester);
    expect(World.settings.zoomPercent, 100);
    if (find.byKey(const Key('zoom-in')).evaluate().isEmpty) await World.tapInView(tester, 'options-menu');
    await tester.tap(find.byKey(const Key('zoom-in')));
    await World.settle(tester);
    expect(World.settings.zoomPercent, 110);
  });

  // Harm: in a narrow window, where the settings open as a dialog, a person without the keys cannot zoom at all.
  testWidgets('the Zoom row stands in the narrow window\'s Options too', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await World.settle(tester);
    await World.tapInView(tester, 'bar-overflow');
    await tester.tap(find.text('Options').last);
    await World.settle(tester);
    expect(find.text('100 %'), findsOneWidget);
    await tester.tap(find.byKey(const Key('zoom-in')));
    await World.settle(tester);
    expect(World.settings.zoomPercent, 110);
    expect(tester.takeException(), isNull);
  });
}
