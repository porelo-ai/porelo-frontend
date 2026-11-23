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

  /// Opens the settings menu from the keyboard alone: its button focused, then Enter.
  Future<void> openByKeyboard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await World.startBackend(World.work);
    await World.startApp(tester);
    await World.settle(tester);
    final button = find.byKey(const Key('options-menu'));
    Focus.of(tester.element(find.descendant(of: button, matching: find.byType(Icon)).first)).requestFocus();
    await World.settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await World.settle(tester);
  }

  /// Whether the keyboard is on the settings menu's button.
  bool onTheButton() => FocusManager.instance.primaryFocus?.debugLabel == 'options-menu';

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

  // Harm: a person on the keyboard opens the settings menu but cannot reach a choice in it: the arrows walk the page
  // behind it.
  testWidgets('the settings menu is walked by the keyboard alone, into a submenu and its choice', (tester) async {
    await openByKeyboard(tester);

    bool onAppearance() {
      final focused = FocusManager.instance.primaryFocus?.context;
      return focused != null &&
          find.descendant(of: find.byWidget(focused.widget), matching: find.text('Appearance')).evaluate().isNotEmpty;
    }

    for (var step = 0; step < 8 && !onAppearance(); step++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await World.settle(tester);
    }
    expect(onAppearance(), isTrue, reason: 'the arrows walk the menu, not the page behind it');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await World.settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await World.settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await World.settle(tester);
    expect(World.settings.appearance, isNot(ThemeMode.system), reason: 'a choice in the submenu is taken by Enter');
    expect(onTheButton(), isTrue, reason: 'after a choice the keyboard is back on the menu\'s button');
  });

  // Harm: a person on the keyboard who leaves the settings menu with Escape has lost their place: the next Tab starts
  // from the top of the window.
  testWidgets('Escape closes the settings menu and gives the keyboard back to its button', (tester) async {
    await openByKeyboard(tester);
    expect(find.byKey(const Key('zoom-reset')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await World.settle(tester);

    expect(find.byKey(const Key('zoom-reset')), findsNothing, reason: 'Escape closes the menu');
    expect(onTheButton(), isTrue, reason: 'the keyboard is back where it came from');
  });

  // Harm: a person who opened the settings menu with the pointer presses Enter, and the window jumps back to its usual
  // size through a button nothing showed as focused.
  testWidgets('after the pointer opens the settings menu, Enter leaves the zoom alone', (tester) async {
    await open(tester);
    // Smaller, so the menu's button stays in the bar rather than its overflow.
    await tester.tap(find.byKey(const Key('zoom-out')));
    await World.settle(tester);
    expect(World.settings.zoomPercent, 90);
    if (find.byKey(const Key('zoom-reset')).evaluate().isEmpty) await World.tapInView(tester, 'options-menu');
    expect(find.text('90 %'), findsOneWidget, reason: 'the pointer opened the menu');

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await World.settle(tester);

    expect(World.settings.zoomPercent, 90, reason: 'Enter pressed no button the menu did not show as focused');
  });

  // Harm: a press on the settings button that slides off it opens nothing, yet the next opening from the keyboard is
  // taken for the pointer's, and the arrows walk the page behind the menu again.
  testWidgets('a press that slides off the settings button leaves the keyboard\'s next opening its own', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await World.startBackend(World.work);
    await World.startApp(tester);
    await World.settle(tester);
    final button = find.byKey(const Key('options-menu'));
    final press = await tester.startGesture(tester.getCenter(button));
    await press.moveTo(const Offset(640, 400));
    await press.up();
    await World.settle(tester);
    expect(find.byKey(const Key('zoom-reset')), findsNothing, reason: 'the slid-off press opened nothing');

    Focus.of(tester.element(find.descendant(of: button, matching: find.byType(Icon)).first)).requestFocus();
    await World.settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await World.settle(tester);

    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'options-menu first choice',
      reason: 'opened from the keyboard, the menu gives its first entry the keyboard',
    );
  });

  // Harm: a person who opened the settings menu with the pointer from a focused button and leaves it with Escape has
  // lost their place.
  testWidgets('Escape after the pointer opened the settings menu gives the keyboard back to where it was', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await World.startBackend(World.work);
    await World.startApp(tester);
    await World.settle(tester);
    final button = find.byKey(const Key('options-menu'));
    Focus.of(tester.element(find.descendant(of: button, matching: find.byType(Icon)).first)).requestFocus();
    await World.settle(tester);
    await World.tapInView(tester, 'options-menu');
    expect(find.byKey(const Key('zoom-reset')), findsOneWidget, reason: 'the pointer opened the menu');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await World.settle(tester);

    expect(find.byKey(const Key('zoom-reset')), findsNothing, reason: 'Escape closes the menu');
    expect(onTheButton(), isTrue, reason: 'the keyboard is back where it was before the menu opened');
  });
}
