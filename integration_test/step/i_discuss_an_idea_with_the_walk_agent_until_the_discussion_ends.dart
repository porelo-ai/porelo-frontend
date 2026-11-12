import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/idea_walk.dart';
import '../support/rehearsal.dart';

/// Usage: I discuss an idea with the walk agent until the discussion ends
Future<void> iDiscussAnIdeaWithTheWalkAgentUntilTheDiscussionEnds(WidgetTester tester) =>
    walked(tester, '2 the person discusses an idea with ${Walk.agent} until it ends', () async {
      await noteTheTasks();
      await chooseFromTheMenu(tester, find.byKey(const Key('planning-board-menu')), 'Discuss an idea…');
      final words = find.byKey(const Key('planning-idea-words'));
      await pumpUntil(tester, () => words.evaluate().isNotEmpty, what: 'the idea dialog');
      await tester.enterText(words, Walk.idea);
      await pumpFor(tester);
      await tester.tap(find.byKey(const Key('planning-idea-discuss')));
      await pumpFor(tester);
      final agent = find.byKey(const Key('discussion-agent'));
      final refused = find.byKey(const Key('discussion-not-offered'));
      await pumpUntil(
        tester,
        () => agent.evaluate().isNotEmpty || refused.evaluate().isNotEmpty,
        timeout: const Duration(minutes: 2),
        what: 'the discussion form to offer its agents',
      );
      if (refused.evaluate().isNotEmpty) fail('no discussion is offered: ${tester.widget<Text>(refused).data}');
      await tester.tap(agent);
      await pumpFor(tester);
      final choice = find.byKey(ValueKey<String>('start-agent-choice ${Walk.agent}'));
      await pumpUntil(tester, () => choice.evaluate().isNotEmpty, what: 'the machine to offer ${Walk.agent}');
      await tester.tap(choice.last);
      await pumpFor(tester);
      await tester.enterText(find.byKey(const Key('discussion-model')), Walk.model);
      await pumpFor(tester);
      final start = find.byKey(const Key('discussion-start'));
      await pumpUntil(
        tester,
        () => tester.widget<ButtonStyleButton>(start).onPressed != null,
        timeout: const Duration(minutes: 1),
        what: 'Start in the discussion form',
      );
      await tester.tap(start);
      await pumpFor(tester);
      Walk.discussion = theContainerOf(await theNewTask(tester, 'the discussion'));
      // The window shows the discussion's session at once; the person talks there, as at a keyboard.
      final terminal = await theSessionsTerminal(tester);
      await untilQuiet(tester, terminal, quiet: const Duration(minutes: 1), within: Walk.taskDeadline);
      await say(
        tester,
        terminal,
        'I agree with the idea exactly as written; it answers every question. Write idea.json now, then say so.',
      );
      await untilQuiet(tester, terminal, quiet: const Duration(seconds: 90), within: Walk.taskDeadline);
      await say(tester, terminal, Walk.quit);
      // The agent ends into the session's shell, and the session ends with that shell, as the person leaves it.
      await untilQuiet(tester, terminal, quiet: const Duration(seconds: 10), within: const Duration(minutes: 2));
      await say(tester, terminal, 'exit');
      // The window removes the ended discussion once the planner saved its idea, which may come first.
      await untilItEnds(tester, Walk.discussion!, within: const Duration(minutes: 5), goneIsEnded: true);
    });
