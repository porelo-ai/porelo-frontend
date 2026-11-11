// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_planning.dart';
import './step/the_app_is_running.dart';
import './step/i_open_the_planning_board.dart';
import './step/i_offer_the_idea_for_discussion.dart';
import './step/the_discussions_start_says.dart';
import './step/i_start_the_discussion_with_the_agent.dart';
import './step/the_machine_starts_a_discussion_over_every_repository_with_the_agent.dart';
import './step/i_turn_the_discussions_start_away.dart';
import './step/no_discussion_is_started.dart';
import './step/the_discussions_session_is_on_screen.dart';

void main() {
  group('''Discuss an idea with an agent from the planning board''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithPlanning(tester);
      await theAppIsRunning(tester);
      await iOpenThePlanningBoard(tester);
    }

    testWidgets('''The person picks the agent and the discussion reads every repository, read only''', (tester) async {
      await bddSetUp(tester);
      await iOfferTheIdeaForDiscussion(tester, 'Let the board show who is at work');
      await theDiscussionsStartSays(tester, 'every repository of the project, read only');
      await iStartTheDiscussionWithTheAgent(tester, 'other-agent');
      await theMachineStartsADiscussionOverEveryRepositoryWithTheAgent(tester, 'other-agent');
    });
    testWidgets('''Turning the discussion's Start away starts nothing''', (tester) async {
      await bddSetUp(tester);
      await iOfferTheIdeaForDiscussion(tester, 'Let the board show who is at work');
      await iTurnTheDiscussionsStartAway(tester);
      await noDiscussionIsStarted(tester);
    });
    testWidgets('''A started discussion opens its session''', (tester) async {
      await bddSetUp(tester);
      await iOfferTheIdeaForDiscussion(tester, 'Let the board show who is at work');
      await iStartTheDiscussionWithTheAgent(tester, 'other-agent');
      await theDiscussionsSessionIsOnScreen(tester);
    });
  });
}
