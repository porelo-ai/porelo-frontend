import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/ui/command_menu.dart';
import 'package:porelo_frontend/src/ui/expandable_list_row.dart';

import '../support/menu_entries.dart';

/// A command menu whose commands name submenus: their order, their keyboard, their highlight and their right click.
void main() {
  late List<String> ran;
  late int viewsClosed;

  setUp(() {
    ran = [];
    viewsClosed = 0;
  });

  Command command(String id, {String? submenu, bool danger = false, bool hidden = false, String? unavailable}) =>
      Command(
        id: id,
        label: 'Do $id',
        group: 'Test',
        submenu: submenu,
        danger: danger,
        hidden: hidden,
        unavailable: unavailable,
        run: () => ran.add(id),
      );

  Future<void> show(WidgetTester tester, Widget child, {Size size = const Size(1280, 800)}) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Shortcuts(
          // As the window's frame does: Escape closes the view behind the menu.
          shortcuts: const {SingleActivator(LogicalKeyboardKey.escape): _CloseView()},
          child: Actions(
            actions: {_CloseView: CallbackAction<_CloseView>(onInvoke: (_) => viewsClosed++)},
            child: Focus(
              autofocus: true,
              child: Scaffold(
                body: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    child,
                    TextButton(onPressed: () => ran.add('under'), child: const Text('What lies under')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder entry(String id) => find.byKey(ValueKey<String>(id));
  Finder submenu(String name) => find.byKey(Key('submenu $name'));
  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byTooltip('What can be done'));
    await tester.pumpAndSettle();
  }

  // Harm: a long menu buries what a person reaches for most, or puts a removal between harmless entries.
  testWidgets('entries without a submenu stand at the top in their order, submenus where first named, danger last', (
    tester,
  ) async {
    await show(
      tester,
      CommandMenu(
        tooltip: 'What can be done',
        commands: [
          command('a'),
          command('x1', submenu: 'X'),
          command('b'),
          command('del', danger: true),
          command('y1', submenu: 'Y'),
          command('x2', submenu: 'X'),
          command('z1', submenu: 'Z', hidden: true),
          command('c'),
        ],
      ),
    );
    await open(tester);
    final top = [entry('a'), submenu('X'), entry('b'), submenu('Y'), entry('c'), entry('del')];
    for (final each in top) {
      expect(each, findsOneWidget);
    }
    final heights = [for (final each in top) tester.getTopLeft(each).dy];
    expect(heights, [...heights]..sort(), reason: 'a, X, b, Y, c, then the removal last');
    expect(submenu('Z'), findsNothing, reason: 'a submenu with nothing offered is left out');
    expect(entry('x1'), findsNothing, reason: 'a submenu\'s entries wait until it opens');

    await tester.tap(submenu('X'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(entry('x1')).dy, lessThan(tester.getTopLeft(entry('x2')).dy));
    await tester.tap(entry('x2'));
    await tester.pumpAndSettle();
    expect(ran, ['x2']);
    expect(entry('a'), findsNothing, reason: 'a choice closes the whole menu');
  });

  // Harm: a person sees a group of actions vanish when none of them can run now, and never learns why.
  testWidgets('a submenu whose entries all cannot run is offered grey, each reason readable inside', (tester) async {
    final semantics = tester.ensureSemantics();
    await show(
      tester,
      CommandMenu(
        tooltip: 'What can be done',
        commands: [
          command('a'),
          command('g1', submenu: 'Grey', unavailable: 'it is not running'),
          command('g2', submenu: 'Grey', unavailable: 'the machine is not answering'),
        ],
      ),
    );
    await open(tester);
    expect(tester.widget<SubmenuButton>(submenu('Grey')).style?.foregroundColor, isNotNull, reason: 'drawn grey');
    expect(tester.getSemantics(find.text('Grey')).getSemanticsData().hint, 'none of its entries can run now');
    await tester.tap(submenu('Grey'));
    await tester.pumpAndSettle();
    expect(find.text('Unavailable: it is not running'), findsOneWidget);
    expect(find.text('Unavailable: the machine is not answering'), findsOneWidget);
    expect(tester.widget<MenuItemButton>(entry('g1')).enabled, isFalse);
    await tester.tap(entry('g1'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(ran, isEmpty);
    semantics.dispose();
  });

  // Harm: a person on the keyboard is stuck in a grey submenu, or Escape there closes the view behind the menu.
  testWidgets('the keyboard opens a grey submenu, leaves it with the left arrow and the menu with Escape', (
    tester,
  ) async {
    await show(
      tester,
      CommandMenu(
        tooltip: 'What can be done',
        commands: [
          command('a'),
          command('g1', submenu: 'Grey', unavailable: 'it is not running'),
        ],
      ),
    );
    final button = find.byTooltip('What can be done');
    Focus.of(tester.element(find.descendant(of: button, matching: find.byType(Icon)))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_focusedIn(entry('a')), isTrue, reason: 'opened from the keyboard, the first entry has the keyboard');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_focusedIn(submenu('Grey')), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('Unavailable: it is not running'), findsOneWidget, reason: 'the reason reads inside');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.text('Unavailable: it is not running'), findsNothing, reason: 'the left arrow leaves the submenu');
    expect(entry('a'), findsOneWidget, reason: 'and keeps the menu');
    expect(_focusedIn(submenu('Grey')), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(entry('a'), findsNothing, reason: 'Escape closes the menu');
    expect(viewsClosed, 0, reason: 'and never the view behind it');
    expect(_focusedIn(button), isTrue, reason: 'the keyboard is back on the menu\'s button');
    expect(ran, isEmpty);
  });

  // Harm: a person who opened the menu with the pointer and presses Escape loses the view they work in.
  testWidgets('Escape in a menu the pointer opened closes the menu, never the view behind it', (tester) async {
    await show(
      tester,
      CommandMenu(
        tooltip: 'What can be done',
        commands: [
          command('a'),
          command('x1', submenu: 'X'),
        ],
      ),
    );
    await open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(entry('a'), findsNothing, reason: 'Escape closes the menu');
    expect(viewsClosed, 0, reason: 'and never the view behind it');
  });

  // Harm: a tap that only meant to close the menu presses whatever lay under it.
  testWidgets('a tap outside closes the menu without pressing what lies under it', (tester) async {
    await show(
      tester,
      CommandMenu(
        tooltip: 'What can be done',
        commands: [
          command('a'),
          command('x1', submenu: 'X'),
        ],
      ),
    );
    await open(tester);
    await tester.tap(find.text('What lies under'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(entry('a'), findsNothing, reason: 'the tap closed the menu');
    expect(ran, isEmpty, reason: 'and pressed nothing under it');
  });

  // Harm: the finder goes to an action inside a submenu and the person is left looking at a closed menu.
  testWidgets('the finder\'s destination inside a submenu opens it, marked and focused, before it says so', (
    tester,
  ) async {
    var shown = 0;
    bool? markedWhenShown;
    await show(
      tester,
      CommandMenu(
        tooltip: 'What can be done',
        highlight: 'x2',
        onShown: () {
          shown++;
          markedWhenShown = _focusedIn(find.byKey(const Key('highlighted')));
        },
        commands: [
          command('a'),
          command('x1', submenu: 'X'),
          command('x2', submenu: 'X'),
        ],
      ),
    );
    await tester.pumpAndSettle();
    final marked = find.byKey(const Key('highlighted'));
    expect(marked, findsOneWidget);
    expect(find.descendant(of: marked, matching: find.text('Do x2')), findsOneWidget);
    expect(entry('x1'), findsOneWidget, reason: 'its submenu is open');
    expect(shown, 1);
    expect(markedWhenShown, isTrue, reason: 'the entry was marked and focused before the finder was told');
  });

  // Harm: a right click on a row offers less than its button, or runs an entry of another row.
  testWidgets('a right click in the row opens its own menu where the pointer is, submenus included', (tester) async {
    await show(
      tester,
      CommandMenuArea(
        child: SizedBox(
          width: 600,
          child: Row(
            children: [
              const Expanded(child: Text('the row')),
              CommandMenu(
                tooltip: 'What can be done',
                commands: [
                  command('a'),
                  command('x1', submenu: 'X'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    final at = tester.getCenter(find.text('the row'));
    await tester.tapAt(at, buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(entry('a'), findsOneWidget);
    expect((tester.getTopLeft(entry('a')) - at).distance, lessThan(_near), reason: 'where the pointer is');
    await tester.tap(submenu('X'));
    await tester.pumpAndSettle();
    await tester.tap(entry('x1'));
    await tester.pumpAndSettle();
    expect(ran, ['x1']);
  });

  // Harm: on a phone-wide window a long reason pushes the menu past the window's edge, or a row asking the menu's
  // width fails.
  testWidgets('a menu with long reasons stays inside a 390 wide window, in a leaf row', (tester) async {
    const long =
        'nothing recorded which project it belongs to, and its project says whom it may talk to, so it is not '
        'offered here';
    await show(
      tester,
      SizedBox(
        width: 390,
        child: LeafListRow(
          title: 'a task',
          subtitle: const Text('its project'),
          leading: const Icon(Icons.play_circle_outline),
          state: 'Running',
          trailing: CommandMenu(
            tooltip: 'What can be done',
            commands: [
              command('a', unavailable: long),
              command('x1', submenu: 'X', unavailable: long),
            ],
          ),
        ),
      ),
      size: const Size(390, 800),
    );
    expect(tester.takeException(), isNull);
    await open(tester);
    expect(tester.takeException(), isNull);
    expect(tester.getRect(entry('a')).right, lessThanOrEqualTo(390));
    await tester.tap(submenu('X'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getRect(entry('x1')).right, lessThanOrEqualTo(390));
    expect(tester.getRect(entry('x1')).left, greaterThanOrEqualTo(0));
  });

  /// A menu whose highlight, commands and enabling the test changes while it is shown.
  Future<StateSetter> showChanging(
    WidgetTester tester, {
    required List<Command> Function() commands,
    String? Function()? highlight,
    VoidCallback? onShown,
    bool settle = true,
  }) async {
    late StateSetter change;
    tester.view
      ..physicalSize = const Size(1280, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Shortcuts(
          shortcuts: const {SingleActivator(LogicalKeyboardKey.escape): _CloseView()},
          child: Actions(
            actions: {_CloseView: CallbackAction<_CloseView>(onInvoke: (_) => viewsClosed++)},
            child: Focus(
              autofocus: true,
              child: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    change = setState;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CommandMenuArea(
                          child: SizedBox(
                            width: 600,
                            child: Row(
                              children: [
                                const Expanded(child: Text('the row')),
                                CommandMenu(
                                  tooltip: 'What can be done',
                                  highlight: highlight?.call(),
                                  onShown: onShown,
                                  commands: commands(),
                                ),
                              ],
                            ),
                          ),
                        ),
                        TextButton(onPressed: () => ran.add('under'), child: const Text('What lies under')),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
    return change;
  }

  Future<void> focusTheButton(WidgetTester tester) async {
    final button = find.byTooltip('What can be done');
    Focus.of(tester.element(find.descendant(of: button, matching: find.byType(Icon)))).requestFocus();
    await tester.pump();
  }

  // Harm: the finder goes to an action of a task whose menu is already open, and the menu it reopens marks nothing
  // and runs nothing.
  testWidgets('a finder pick on a menu already open reopens it marked, and the marked entry runs', (tester) async {
    String? highlight;
    final change = await showChanging(
      tester,
      highlight: () => highlight,
      onShown: () => highlight = null,
      commands: () => [command('a'), command('x1', submenu: 'X'), command('x2', submenu: 'X')],
    );
    await open(tester);
    change(() => highlight = 'x2');
    await tester.pumpAndSettle();
    final marked = find.byKey(const Key('highlighted'));
    expect(marked, findsOneWidget, reason: 'the reopened menu marks where the finder went');
    expect(find.descendant(of: marked, matching: find.text('Do x2')), findsOneWidget);
    await tester.tap(marked);
    await tester.pumpAndSettle();
    expect(ran, ['x2'], reason: 'and runs it');
  });

  // Harm: a right click on a row whose menu is open leaves a menu that runs nothing.
  testWidgets('a right click on a row whose menu is open closes it, and the next opens one whose entries run', (
    tester,
  ) async {
    await showChanging(tester, commands: () => [command('a'), command('x1', submenu: 'X')]);
    await open(tester);
    final row = tester.getCenter(find.text('the row'));
    await tester.tapAt(row, buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(entry('a'), findsNothing, reason: 'a press outside the open menu closes it, and goes no further');
    await tester.tapAt(row, buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(entry('a'));
    await tester.pumpAndSettle();
    expect(ran, ['a']);
  });

  // Harm: a person who opened the menu with the pointer reaches for the arrow keys and walks the page behind it.
  testWidgets('after the pointer opens the menu the down arrow walks into it, and Escape closes only it', (
    tester,
  ) async {
    await showChanging(tester, commands: () => [command('a'), command('x1', submenu: 'X')]);
    await open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_focusedIn(find.text('What lies under')), isFalse, reason: 'the arrow stays in the menu');
    expect(_focusedIn(entry('a')) || _focusedIn(submenu('X')), isTrue, reason: 'it walks into the menu');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(entry('a'), findsNothing, reason: 'Escape closes the menu');
    expect(viewsClosed, 0, reason: 'and never the view behind it');
  });

  // Harm: a menu opened by a right click leaves the keyboard on the page, so the arrows and Escape act behind it.
  testWidgets('after a right click the down arrow walks into the menu, and Escape closes only it', (tester) async {
    await showChanging(tester, commands: () => [command('a'), command('x1', submenu: 'X')]);
    await tester.tapAt(tester.getCenter(find.text('the row')), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_focusedIn(find.text('What lies under')), isFalse, reason: 'the arrow stays in the menu');
    expect(_focusedIn(entry('a')) || _focusedIn(submenu('X')), isTrue, reason: 'it walks into the menu');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(entry('a'), findsNothing, reason: 'Escape closes the menu');
    expect(viewsClosed, 0, reason: 'and never the view behind it');
  });

  // Harm: a menu with nothing to run, opened from the keyboard, hands the arrows and Escape to the page behind it.
  testWidgets('a keyboard-opened menu with nothing runnable keeps the arrows, and Escape closes only it', (
    tester,
  ) async {
    await showChanging(
      tester,
      commands: () => [command('a', unavailable: 'it is not running'), command('b', unavailable: 'it is not running')],
    );
    await focusTheButton(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(entry('a'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_focusedIn(find.text('What lies under')), isFalse, reason: 'the arrow stays with the menu');
    expect(entry('a'), findsOneWidget, reason: 'and the menu stays open');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(entry('a'), findsNothing, reason: 'Escape closes the menu');
    expect(viewsClosed, 0, reason: 'and never the view behind it');
    expect(_focusedIn(find.byTooltip('What can be done')), isTrue, reason: 'the keyboard is back on the button');
  });

  // Harm: a row's last action goes while its menu is open, and the menu vanishes, leaving it half-open for the next
  // opening, which then marks and runs what the earlier one was opened for.
  testWidgets('a menu whose last command goes while open stays, and opens afresh once it is back', (tester) async {
    var offered = true;
    String? highlight = 'a';
    final change = await showChanging(
      tester,
      highlight: () => highlight,
      onShown: () => highlight = null,
      commands: () => [if (offered) command('a')],
    );
    expect(find.byKey(const Key('highlighted')), findsOneWidget, reason: 'the finder opened it on a');
    change(() => offered = false);
    await tester.pumpAndSettle();
    expect(find.text('Unavailable: no longer offered here'), findsOneWidget, reason: 'the open menu stays');
    await tester.tap(find.text('Do a'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(ran, isEmpty);
    await tester.tapAt(const Offset(1000, 700));
    await tester.pumpAndSettle();
    expect(find.text('Unavailable: no longer offered here'), findsNothing, reason: 'a tap outside closes it');
    expect(find.byTooltip('What can be done'), findsNothing, reason: 'closed, a menu offering nothing is not drawn');

    change(() => offered = true);
    await tester.pumpAndSettle();
    await open(tester);
    expect(find.byKey(const Key('highlighted')), findsNothing, reason: 'a new opening marks nothing');
    await tester.tap(entry('a'));
    await tester.pumpAndSettle();
    expect(ran, ['a'], reason: 'and runs for its row');
  });

  // Harm: a person closes the menu the finder is opening, and it opens again by itself, or the finder is told it
  // showed an entry nobody saw.
  testWidgets('a menu closed before the finder\'s submenu opens stays closed, and the finder is not told', (
    tester,
  ) async {
    var shown = 0;
    await showChanging(
      tester,
      highlight: () => 'x2',
      onShown: () => shown++,
      commands: () => [command('a'), command('x1', submenu: 'X'), command('x2', submenu: 'X')],
      settle: false,
    );
    // The menu opened at the end of the first frame; its submenu would open at the end of the next.
    // The person presses the menu's button again, which closes it.
    await tester.tap(find.byTooltip('What can be done'));
    await tester.pumpAndSettle();
    expect(entry('a'), findsNothing, reason: 'the menu stays closed');
    expect(entry('x1'), findsNothing, reason: 'and so does its submenu');
    expect(shown, 0, reason: 'the finder is not told of an entry nobody saw');
    expect(tester.takeException(), isNull);
  });

  // Harm: a keyboard opening whose first row is a submenu opens that submenu by itself, and the person lands two
  // levels deep.
  testWidgets('a keyboard opening whose first row is a submenu lands on it with the submenu closed', (tester) async {
    await showChanging(tester, commands: () => [command('x1', submenu: 'X'), command('a')]);
    await focusTheButton(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_focusedIn(submenu('X')), isTrue, reason: 'the keyboard is on the first row');
    expect(entry('x1'), findsNothing, reason: 'which stays closed until the person opens it');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(entry('x1'), findsOneWidget, reason: 'the right arrow opens it');
  });

  // Harm: a step looking for an entry misses one in a submenu that carries no key, or leaves a submenu open behind
  // it, and the next step reads that submenu's entries as the menu's own.
  testWidgets('the tests\' way to an entry opens unkeyed submenus too, and leaves none open when it is absent', (
    tester,
  ) async {
    final menu = MenuController();
    await show(
      tester,
      MenuAnchor(
        controller: menu,
        menuChildren: [
          MenuItemButton(onPressed: () {}, child: const Text('Top')),
          SubmenuButton(
            menuChildren: [MenuItemButton(onPressed: () {}, child: const Text('Inside A'))],
            child: const Text('A'),
          ),
          SubmenuButton(
            menuChildren: [MenuItemButton(onPressed: () {}, child: const Text('Inside B'))],
            child: const Text('B'),
          ),
        ],
        child: const Text('anchor'),
      ),
    );
    menu.open();
    await tester.pumpAndSettle();
    expect(await revealMenuEntryLabeled(tester, 'Inside B'), findsOneWidget, reason: 'found in an unkeyed submenu');
    expect(await revealMenuEntryLabeled(tester, 'Nowhere'), findsNothing);
    expect(find.text('Inside A'), findsNothing, reason: 'no submenu is left open');
    expect(find.text('Inside B'), findsNothing, reason: 'no submenu is left open');
    expect(find.text('Top'), findsOneWidget, reason: 'the menu itself stays open');
  });
}

/// How near the pointer a menu opened by a right click starts.
const _near = 48.0;

/// Whether the keyboard is on [found] or inside it.
bool _focusedIn(Finder found) {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return false;
  final targets = found.evaluate().toSet();
  var inside = false;
  focused.visitAncestorElements((ancestor) {
    inside = targets.contains(ancestor);
    return !inside;
  });
  return inside || targets.contains(focused);
}

class _CloseView extends Intent {
  const _CloseView();
}
