import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/ui/machine_view.dart';

import '../features/support/world.dart';

void main() {
  Future<void> showTiles(WidgetTester tester, List<Command> commands) async {
    tester.view
      ..physicalSize = const Size(1280, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Wrap(
            children: <Widget>[
              for (final command in commands)
                CommandTile(
                  key: ValueKey<String>(command.id),
                  command: command,
                  icon: Icons.play_circle_outline,
                  description: 'Run this command.',
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Harm: a tile dispatches a neighboring command or dispatches its own twice.
  testWidgets('a tile runs exactly its command once per press', (tester) async {
    final ran = <String>[];
    await showTiles(tester, <Command>[
      Command(id: 'first', label: 'First', group: 'Work', run: () => ran.add('first')),
      Command(id: 'second', label: 'Second', group: 'Work', run: () => ran.add('second')),
    ]);
    await tester.tap(find.text('Second'));
    await World.settle(tester);
    expect(ran, <String>['second']);
    await tester.tap(find.text('First'));
    await World.settle(tester);
    expect(ran, <String>['second', 'first']);
  });

  // Harm: an action runs when its command refuses it, including after state changes.
  testWidgets('a refused command shows its reason and never runs from its tile', (tester) async {
    var runs = 0;
    final command = Command(id: 'action', label: 'Action', group: 'Work', run: () => runs++);
    await showTiles(tester, <Command>[command]);
    await tester.tap(find.text('Action'));
    expect(runs, 1);
    await showTiles(tester, <Command>[command.unless('the machine is not answering')]);
    expect(find.byTooltip('the machine is not answering'), findsOneWidget);
    await tester.tap(find.text('Action'));
    await World.settle(tester);
    expect(runs, 1);
  });
}
