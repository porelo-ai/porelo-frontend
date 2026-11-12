import 'package:flutter/material.dart';
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

  PopupMenuItem<String> entry(WidgetTester tester, String id) =>
      tester.widget<PopupMenuItem<String>>(find.byKey(ValueKey<String>(id)));

  // Harm: a menu opened for one forge removes another one of the list, drawn in its place while it was open.
  testWidgets('a menu rebuilt for another row while open runs nothing of that row', (tester) async {
    final (row, change) = await open(tester);
    change(() => row.name = 'beta');
    await tester.pump();
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

  // Harm: a press in the frame between the view's change and the menu's redraw runs what can no longer run.
  testWidgets('choosing an entry still drawn runnable runs nothing once the view says it cannot run', (tester) async {
    final (row, change) = await open(tester);
    change(() => row.removable = false);
    // One frame: the view has changed, and the open menu redraws only in the next.
    await tester.pump();
    expect(entry(tester, 'forge.remove').enabled, isTrue, reason: 'the gap this test is about');
    await tester.tap(find.textContaining('Remove alpha'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(row.ran, isEmpty);
  });

  // Harm: a view taken away before the menu's late update fails the window on it.
  testWidgets('a menu taken away before its update after a change is not updated', (tester) async {
    final (row, change) = await open(tester);
    // The change is built in the last phase of a frame, so the menu's update waits for the end of the next one, and
    // that next frame takes the menu away before it.
    tester.binding.addPostFrameCallback((_) {
      change(() => row.removable = false);
      tester.binding.buildOwner!.buildScope(tester.binding.rootElement!);
    });
    tester.binding.scheduleFrame();
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
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
  ];
}
