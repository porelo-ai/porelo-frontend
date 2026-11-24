import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/ui/command_menu.dart';

/// An open command menu follows what its view offers now, and only for the thing it was opened for.
void main() {
  Future<(_Row, StateSetter)> open(WidgetTester tester) async {
    final row = _Row([]);
    late StateSetter change;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              change = setState;
              return Align(
                alignment: Alignment.topLeft,
                // Unkeyed, as a row of a list that is rebuilt for another row in its place.
                child: CommandMenu(commands: row.commands, tooltip: 'What can be done with ${row.name}'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byType(CommandMenu));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    return (row, change);
  }

  MenuItemButton entry(WidgetTester tester, String id) =>
      tester.widget<MenuItemButton>(find.byKey(ValueKey<String>(id)));

  Future<void> openName(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('submenu Name')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  // Harm: a menu opened for one forge removes another one of the list, drawn in its place while it was open.
  testWidgets('a menu rebuilt for another row while open runs nothing of that row', (tester) async {
    final (row, change) = await open(tester);
    change(() => row.name = 'beta');
    await tester.pump();
    expect(entry(tester, 'forge.remove').enabled, isFalse, reason: 'the menu was opened for alpha');
    await tester.tap(find.textContaining('Remove'), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(row.ran, isEmpty);
  });

  // Harm: an action gone from the view while its menu is open still runs from it.
  testWidgets('an entry whose command is gone while the menu is open is grey and runs nothing', (tester) async {
    final (row, change) = await open(tester);
    change(() => row.offered = false);
    await tester.pump();
    await tester.pump();
    expect(entry(tester, 'forge.remove').enabled, isFalse);
    expect(find.textContaining('Unavailable: no longer offered here'), findsOneWidget);
    await tester.tap(find.textContaining('Remove alpha'), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(row.ran, isEmpty);
  });

  // Harm: a press in the frame after the view's change runs what can no longer run.
  testWidgets('choosing an entry once the view says it cannot run runs nothing', (tester) async {
    final (row, change) = await open(tester);
    change(() => row.removable = false);
    await tester.pump();
    expect(entry(tester, 'forge.remove').enabled, isFalse, reason: 'the open menu follows in the same frame');
    await tester.tap(find.textContaining('Remove alpha'), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(row.ran, isEmpty);
  });

  // Harm: an entry inside an open submenu keeps offering what the view no longer can, or never offers what it now can.
  testWidgets('an entry of an open submenu turns grey and runnable again as the view changes', (tester) async {
    final (row, change) = await open(tester);
    await openName(tester);
    expect(entry(tester, 'forge.rename').enabled, isTrue);
    change(() => row.renamable = false);
    await tester.pump();
    expect(entry(tester, 'forge.rename').enabled, isFalse);
    expect(find.textContaining('Unavailable: a rename is under way'), findsOneWidget);
    expect(
      tester.widget<SubmenuButton>(find.byKey(const Key('submenu Name'))).style?.foregroundColor,
      isNotNull,
      reason: 'a submenu with nothing runnable left turns grey too',
    );
    change(() => row.renamable = true);
    await tester.pump();
    expect(entry(tester, 'forge.rename').enabled, isTrue);
    await tester.tap(find.textContaining('Rename alpha'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(row.ran, ['rename alpha']);
  });

  // Harm: a submenu opened for one row renames another one, drawn in its place while it was open.
  testWidgets('a submenu rebuilt for another row while open runs nothing of that row', (tester) async {
    final (row, change) = await open(tester);
    await openName(tester);
    change(() => row.name = 'beta');
    await tester.pump();
    expect(entry(tester, 'forge.rename').enabled, isFalse, reason: 'the menu was opened for alpha');
    await tester.tap(find.textContaining('Rename'), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(row.ran, isEmpty);
  });

  // Harm: a view taken away while its menu is still opening fails the window on the menu's next step.
  testWidgets('a menu taken away before its next opening step is not touched', (tester) async {
    Widget menu({String? highlight}) => MaterialApp(
      home: Scaffold(
        body: CommandMenu(
          highlight: highlight,
          tooltip: 'What can be done',
          commands: [
            Command(id: 'forge.open', label: 'Open alpha', group: 'Forge', run: () {}),
            Command(id: 'forge.rename', label: 'Rename alpha', group: 'Forge', submenu: 'Name', run: () {}),
          ],
        ),
      ),
    );

    // The finder's opening: the menu opens at the end of the first frame, its submenu at the end of the next, which
    // takes the menu away first.
    await tester.pumpWidget(menu(highlight: 'forge.rename'));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);

    // The keyboard's opening: the first entry is given the keyboard at the end of the next frame, which takes the
    // menu away first.
    await tester.pumpWidget(menu());
    final button = find.byTooltip('What can be done');
    Focus.of(tester.element(find.descendant(of: button, matching: find.byType(Icon)))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

/// A row's menu whose commands and row the test changes while it is open.
class _Row {
  _Row(this.ran);

  final List<String> ran;
  String name = 'alpha';
  bool removable = true;
  bool offered = true;
  bool renamable = true;

  List<Command> get commands => [
    if (offered)
      Command(
        id: 'forge.remove',
        label: 'Remove $name',
        group: 'Forge',
        danger: true,
        unavailable: removable ? null : 'a change is under way',
        run: () => ran.add('remove $name'),
      ),
    Command(id: 'forge.open', label: 'Open $name', group: 'Forge', run: () => ran.add('open $name')),
    Command(
      id: 'forge.rename',
      label: 'Rename $name',
      group: 'Forge',
      submenu: 'Name',
      unavailable: renamable ? null : 'a rename is under way',
      run: () => ran.add('rename $name'),
    ),
  ];
}
