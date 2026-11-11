import 'dart:async';
import 'dart:io' show SocketException;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/ui/discussion_start_dialog.dart';
import 'package:porelo_frontend/src/ui/planning_embedding.dart' show DiscussionChoice;
import 'package:porelo_planning/porelo_planning.dart' show PlanningTaskOrder;

void main() {
  final order = PlanningTaskOrder.from({
    'offer': '00000000-0000-4000-8000-00000000d15c',
    'issues': <String>[],
    'role': 'DISCUSSION',
    'agent': 'codex',
    'model': 'gpt-6',
    'mode': 'AGENT',
    'prompt': 'Discuss this idea.',
    'result': 'idea.json',
  });

  Agent agent(String name) => Agent.from({'name': name, 'label': name, 'binary': name});

  Future<AgentsOnTheMachine> listed({Map<String, String> failures = const {}}) async =>
      (agents: [agent('pi'), agent('codex')], failures: failures, shadowed: const <ShadowedAgent>[]);

  Future<Future<DiscussionChoice?>> show(
    WidgetTester tester,
    Future<AgentsOnTheMachine> Function() agents, {
    Future<String?> Function()? whyNot,
  }) async {
    late Future<DiscussionChoice?> chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => chosen = showDialog<DiscussionChoice>(
              context: context,
              builder: (_) => DiscussionStartDialog(
                machine: 'laptop',
                project: 'demo',
                task: order,
                agents: agents,
                whyNot: whyNot ?? () async => null,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return chosen;
  }

  // Harm: the person picks an agent and a model for a discussion the machine cannot start, and learns it only after.
  testWidgets('a machine that cannot read every repository says so, and offers no Start', (tester) async {
    const words =
        "laptop's Porelo cannot read every repository of a project for a discussion; it needs a newer Porelo.";
    await show(tester, listed, whyNot: () async => words);

    expect(find.text(words), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('discussion-start'))).onPressed, isNull);
  });

  // Harm: Start is pressed before the machine said it cannot, and the person learns it only after choosing.
  testWidgets('Start waits until the machine said whether it can start a discussion', (tester) async {
    final answer = Completer<String?>();
    await show(tester, listed, whyNot: () => answer.future);

    expect(tester.widget<FilledButton>(find.byKey(const Key('discussion-start'))).onPressed, isNull);
    answer.complete(null);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byKey(const Key('discussion-start'))).onPressed, isNotNull);
  });

  // Harm: a check that failed - even at once - breaks the form, or lets Start go ahead unknowing.
  testWidgets('a machine that could not say whether it can is said, and offers no Start', (tester) async {
    await show(tester, listed, whyNot: () => throw const SocketException('socket gone'));

    expect(find.textContaining('could not be read: SocketException: socket gone'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('discussion-start'))).onPressed, isNull);
  });

  // Harm: the person cannot tell that the agent reads the whole project and changes nothing.
  testWidgets('it says the project, every repository read only, and the file it hands back', (tester) async {
    await show(tester, listed);

    expect(find.textContaining('demo'), findsWidgets);
    expect(find.textContaining('every repository of the project, read only'), findsOneWidget);
    expect(find.textContaining('idea.json'), findsOneWidget);
  });

  // Harm: the discussion starts with the planner's agent and model, which the person never saw.
  testWidgets('the order\'s agent and model are offered and taken as the person leaves them', (tester) async {
    final chosen = await show(tester, listed);

    expect(find.byKey(const ValueKey('start-agent-choice codex')), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('discussion-model'))).controller?.text, 'gpt-6');
    await tester.tap(find.byKey(const Key('discussion-start')));
    await tester.pumpAndSettle();

    expect(await chosen, (agent: 'codex', model: 'gpt-6'));
  });

  // Harm: the person's own choice is replaced by the planner's.
  testWidgets('the agent and model the person picks are the ones taken', (tester) async {
    final chosen = await show(tester, listed);

    await tester.tap(find.byKey(const Key('discussion-agent')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('start-agent-choice pi')).last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('discussion-model')), 'z-ai/glm-5.3-flash');
    await tester.tap(find.byKey(const Key('discussion-start')));
    await tester.pumpAndSettle();

    expect(await chosen, (agent: 'pi', model: 'z-ai/glm-5.3-flash'));
  });

  // Harm: a dismissed dialog starts the discussion all the same.
  testWidgets('cancelling chooses nothing', (tester) async {
    final chosen = await show(tester, listed);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(await chosen, isNull);
  });

  // Harm: an agent missing from the list looks like one never installed.
  testWidgets('an agent that could not be read is named with why', (tester) async {
    await show(tester, () => listed(failures: {'claude': 'its manifest is broken'}));

    expect(find.text('claude could not be read: its manifest is broken'), findsOneWidget);
  });

  // Harm: a machine that cannot list its agents leaves an endless spinner, or a start with no agent.
  testWidgets('a machine that cannot list its agents says so, and nothing can be started', (tester) async {
    await show(tester, () async => throw StateError('the machine is gone'));

    expect(find.textContaining('the machine is gone'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('discussion-start'))).onPressed, isNull);
  });

  // Harm: a start with no model is sent, which Start refuses after the person waited for it.
  testWidgets('without a model nothing can be started', (tester) async {
    await show(tester, listed);

    await tester.enterText(find.byKey(const Key('discussion-model')), '  ');
    await tester.pump();

    expect(tester.widget<FilledButton>(find.byKey(const Key('discussion-start'))).onPressed, isNull);
  });
}
