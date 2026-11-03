import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/templates.dart';
import 'package:porelo_frontend/src/ui/start_work_view.dart';

import '../features/step/i_start_work_in_this_project.dart';
import '../features/support/world.dart';

void main() {
  // Harm: a dismissed or cleared selection sends an agent override nobody intended to run.
  testWidgets('the start form can return the agent choice to the machine and Esc preserves it', (tester) async {
    await World.startBackend([]);
    await World.startApp(tester);
    World.machines.fleet.selectProject('checkout');
    await iStartWorkInThisProject(tester);
    final field = find.byKey(const Key('start-agent'));

    Future<void> dismissList() async {
      await tester.tap(field);
      await World.settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await World.settle(tester);
      expect(find.byType(StartWorkDialog), findsOneWidget, reason: 'Esc closes only the agent list');
    }

    await dismissList();
    expect(World.starting.agent, isNull, reason: 'Esc must not pick the highlighted agent');
    expect(
      find.descendant(of: field, matching: find.text('The machine chooses')).hitTestable(),
      findsOneWidget,
      reason: 'the closed field must show who chooses when no agent was picked',
    );

    await tester.tap(field);
    await World.settle(tester);
    await tester.tap(find.byKey(const ValueKey<String>('start-agent-choice other-agent')));
    await World.settle(tester);
    expect(World.starting.agent, 'other-agent');
    await dismissList();
    expect(World.starting.agent, 'other-agent', reason: 'Esc must preserve an explicit choice too');

    await tester.tap(field);
    await World.settle(tester);
    await tester.tap(find.text('The machine chooses').last);
    await World.settle(tester);
    expect(World.starting.agent, isNull, reason: 'the machine choice must clear the override');
    expect(find.descendant(of: field, matching: find.text('The machine chooses')).hitTestable(), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('start-go'))).onPressed,
      isNotNull,
      reason: 'returning the choice must allow the machine-selected start',
    );

    await World.starting.openFrom(
      World.backend,
      World.starting.project!,
      const Template(
        name: 'check',
        project: 'checkout',
        agent: 'other-agent',
        mode: Mode.agent,
        prompt: '',
        repository: '',
      ),
    );
    await World.settle(tester);
    await tester.tap(field);
    await World.settle(tester);
    await tester.tap(find.text('The machine chooses').last);
    await World.settle(tester);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('start-go'))).onPressed,
      isNotNull,
      reason: 'a saved job can explicitly return the choice too',
    );
    await tester.tap(find.byKey(const Key('start-go')));
    await World.settle(tester);
    expect(World.backend.starts, hasLength(1));
    expect(World.backend.starts.single.agent, isNull, reason: 'the machine must receive no agent override');
    await World.backend.launch.close();
    await World.settle(tester);
  });
}
