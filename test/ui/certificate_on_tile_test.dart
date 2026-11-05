import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/task_certifying.dart';
import 'package:porelo_frontend/src/ui/command_menu.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';

import '../features/support/world.dart';

void main() {
  Task certified(DateTime until) => Task.from(<String, dynamic>{
    ...wire(World.aTask('p-work', 'p')),
    'certified': true,
    'certifiedUntil': until.toIso8601String(),
  });

  Future<void> onWork(WidgetTester tester, Task task) async {
    await World.startBackend(World.work);
    World.backend.publish(<Task>[task]);
    await World.startApp(tester);
    await World.fleet.refresh(quietly: true);
    World.shell.goTo(Section.work);
    await World.settle(tester);
  }

  // Harm: its pushes begin to be refused and nothing said it was coming.
  testWidgets('work whose certificate ends within a day says so on its tile', (tester) async {
    await onWork(tester, certified(DateTime.now().toUtc().add(const Duration(hours: 5))));
    expect(find.byKey(const Key('tile-certificate')), findsOneWidget);
    expect(find.textContaining('Certify it for another week'), findsWidgets);
  });

  testWidgets('work with a week left says nothing of it', (tester) async {
    await onWork(tester, certified(DateTime.now().toUtc().add(const Duration(days: 6))));
    expect(find.byKey(const Key('tile-certificate')), findsNothing);
  });

  // Harm: the one line that says it worked, or why it did not, is gone before it can be read.
  testWidgets('what certifying says stays, and is not replaced by a refresh', (tester) async {
    final runner = certifyAgainRunner;
    addTearDown(() => certifyAgainRunner = runner);
    certifyAgainRunner = (program, arguments, {inDirectory, environment = const <String, String>{}, input}) async =>
        (code: 0, out: '', err: '');
    final task = certified(DateTime.now().toUtc().add(const Duration(hours: 5)));
    await onWork(tester, task);
    await tester.tap(find.byType(CommandMenu).first);
    await World.settle(tester);
    await tester.tap(find.text('Certify it for another week').last);
    await World.settle(tester);
    expect(find.textContaining('is certified for another week.'), findsWidgets);
    expect(find.textContaining('Refreshed:'), findsNothing);
  });
}
