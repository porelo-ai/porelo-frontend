import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/idea_walk.dart';
import '../support/rehearsal.dart';

/// Usage: I ask for the work of the story to Implementing with the walk agent
Future<void> iAskForTheWorkOfTheStoryToImplementingWithTheWalkAgent(WidgetTester tester) =>
    walked(tester, '5 the person asks for the work to Implementing with ${Walk.agent}', () async {
      await toThePlace(tester, 'planning');
      final crumb = find.byKey(const Key('planning-crumb 0'));
      if (crumb.evaluate().isNotEmpty) {
        await tester.tap(crumb.first);
        await pumpFor(tester);
      }
      await chooseFromTheMenu(tester, find.byKey(Key('planning-menu ${Walk.story}')), 'Start work…');
      final unattended = find.byKey(const Key('story-work-mode UNATTENDED'));
      final refused = find.byKey(const Key('story-work-error'));
      // Opening the form asks the planner for its proposal.
      await pumpUntil(
        tester,
        () => unattended.evaluate().isNotEmpty || refused.evaluate().isNotEmpty,
        timeout: const Duration(minutes: 2),
        what: 'the proposal of the work, unattended',
      );
      if (refused.evaluate().isNotEmpty) fail('the proposal was refused: ${tester.widget<Text>(refused).data}');
      if (find.textContaining('→ Implementing').evaluate().isEmpty) {
        await tester.tap(find.byKey(const Key('story-work-target')));
        await pumpFor(tester);
        await tester.tap(find.text('Implementing').last);
        await pumpUntil(tester, () => unattended.evaluate().isNotEmpty, what: 'the proposal to Implementing');
      }
      await tester.ensureVisible(unattended);
      await tester.tap(unattended);
      await pumpFor(tester);
      const prefix = 'story-work-task ';
      final repositories = [
        for (final each
            in find
                .byWidgetPredicate(
                  (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith(prefix),
                )
                .evaluate())
          (each.widget.key! as ValueKey<String>).value.substring(prefix.length),
      ];
      if (repositories.isEmpty) fail('the proposal names no repository to work in');
      for (final repository in repositories) {
        final agent = find.byKey(Key('story-work-main-agent $repository'));
        await tester.ensureVisible(agent);
        await tester.tap(agent);
        await pumpFor(tester);
        final choice = find.byKey(ValueKey<String>('start-agent-choice ${Walk.agent}'));
        await tester.tap(choice.evaluate().isNotEmpty ? choice.last : find.text(Walk.agent).last);
        await pumpFor(tester);
        final model = find.byKey(Key('story-work-main-model $repository'));
        await tester.ensureVisible(model);
        await tester.enterText(model, Walk.model);
        await pumpFor(tester);
      }
      final start = find.byKey(const Key('story-work-start'));
      await pumpUntil(
        tester,
        () => tester.widget<ButtonStyleButton>(start).onPressed != null,
        timeout: const Duration(minutes: 1),
        what: 'the form to offer its start',
      );
    });
