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
      await fillTheWorkForm(tester, 'Implementing');
    });
