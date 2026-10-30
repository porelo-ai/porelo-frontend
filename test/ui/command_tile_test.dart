import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/ui/command_menu.dart';

import '../features/support/world.dart';

void main() {
  Future<void> showCommands(WidgetTester tester, List<Command> commands) async {
    tester.view
      ..physicalSize = const Size(1280, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              for (final command in commands)
                CommandMenu(key: ValueKey<String>(command.id), commands: [command], tooltip: command.label),
            ],
          ),
        ),
      ),
    );
  }

  // Harm: a tile dispatches a neighboring command or dispatches its own twice.
  testWidgets('a row menu runs exactly its command once per selection', (tester) async {
    final ran = <String>[];
    await showCommands(tester, <Command>[
      Command(id: 'first', label: 'First', group: 'Work', run: () => ran.add('first')),
      Command(id: 'second', label: 'Second', group: 'Work', run: () => ran.add('second')),
    ]);
    await tester.tap(find.byKey(const Key('second')));
    await World.settle(tester);
    await tester.tap(find.text('Second'));
    await World.settle(tester);
    expect(ran, <String>['second']);
    await tester.tap(find.byKey(const Key('first')));
    await World.settle(tester);
    await tester.tap(find.text('First'));
    await World.settle(tester);
    expect(ran, <String>['second', 'first']);
  });

  // Harm: an action runs when its command refuses it, including after state changes.
  testWidgets('a refused command remains unavailable in the row menu', (tester) async {
    var runs = 0;
    final command = Command(id: 'action', label: 'Action', group: 'Work', run: () => runs++);
    await showCommands(tester, <Command>[command]);
    await tester.tap(find.byKey(const Key('action')).first);
    await World.settle(tester);
    await tester.tap(find.text('Action'));
    expect(runs, 1);
    await showCommands(tester, <Command>[command.unless('the machine is not answering')]);
    await tester.tap(find.byKey(const Key('action')).first);
    await World.settle(tester);
    expect(find.textContaining('the machine is not answering'), findsOneWidget);
    await tester.tap(find.text('Action'));
    await World.settle(tester);
    expect(runs, 1);
  });
}
