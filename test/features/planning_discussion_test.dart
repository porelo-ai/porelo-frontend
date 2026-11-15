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
import './step/the_machine_says_while_it_prepares_a_start_and_holds_it.dart';
import './step/the_operation_is_in_front_of_the_board.dart';
import './step/the_operation_shows.dart';
import './step/the_machine_lets_the_start_go_on.dart';
import './step/one_discussion_was_started.dart';
import './step/the_windows_log_is_kept.dart';
import './step/the_machine_refuses_the_discussions_start_with_exit_saying.dart';
import './step/the_windows_log_says.dart';
import './step/the_planning_board_says_once_its_reason_first.dart';
import './step/no_notice_says_a_start_was_refused.dart';
import './step/the_machine_refuses_the_discussions_start_because_is_not_signed_in.dart';
import './step/the_planning_board_says_in_words.dart';
import './step/i_go_to_what_needs_a_person.dart';
import './step/what_needs_a_person_offers_to_sign_in_to_on.dart';
import './step/i_press.dart';
import './step/i_close_the_terminal_of_the_signin.dart';
import './step/the_signin_ends_as.dart';
import './step/what_needs_a_person_no_longer_offers_to_sign_in_to_on.dart';
import './step/the_windows_log_says_nothing_of.dart';

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
    testWidgets('''A discussion pressed on the board opens its operation at once, then its session''', (tester) async {
      await bddSetUp(tester);
      await theMachineSaysWhileItPreparesAStartAndHoldsIt(tester, 'Building the image');
      await iOfferTheIdeaForDiscussion(tester, 'Let the board show who is at work');
      await iStartTheDiscussionWithTheAgent(tester, 'other-agent');
      await theOperationIsInFrontOfTheBoard(tester);
      await theOperationShows(tester, 'Building the image');
      await theMachineLetsTheStartGoOn(tester);
      await theDiscussionsSessionIsOnScreen(tester);
      await oneDiscussionWasStarted(tester);
    });
    testWidgets(
      '''A discussion Start the machine refuses is said in the log, and once on the board, its reason first''',
      (tester) async {
        await bddSetUp(tester);
        await theWindowsLogIsKept(tester);
        await theMachineRefusesTheDiscussionsStartWithExitSaying(
          tester,
          78,
          'porelo: no-homeserver: porelo names no homeserver',
        );
        await iOfferTheIdeaForDiscussion(tester, 'Let the board show who is at work');
        await iStartTheDiscussionWithTheAgent(tester, 'other-agent');
        await theWindowsLogSays(tester, 'Start of a discussion for checkout on this machine was refused');
        await theWindowsLogSays(tester, 'porelo: no-homeserver: porelo names no homeserver');
        await thePlanningBoardSaysOnceItsReasonFirst(tester, 'porelo: no-homeserver: porelo names no homeserver');
        await noNoticeSaysAStartWasRefused(tester);
      },
    );
    testWidgets('''A discussion Start refused for a sign-in names the agent and machine, and Needs you signs it in''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theMachineRefusesTheDiscussionsStartBecauseIsNotSignedIn(tester, 'other-agent');
      await iOfferTheIdeaForDiscussion(tester, 'Let the board show who is at work');
      await iStartTheDiscussionWithTheAgent(tester, 'other-agent');
      await thePlanningBoardSaysInWords(tester, 'Another Agent is not signed in on this machine');
      await iGoToWhatNeedsAPerson(tester);
      await whatNeedsAPersonOffersToSignInToOn(tester, 'Another Agent', 'this machine');
      await iPress(tester, 'Sign in on this machine');
      await iCloseTheTerminalOfTheSignin(tester);
      await theSigninEndsAs(tester, 'SIGNED_IN');
      await whatNeedsAPersonNoLongerOffersToSignInToOn(tester, 'Another Agent', 'this machine');
    });
    testWidgets('''A discussion Start turned away is neither logged as refused nor noticed''', (tester) async {
      await bddSetUp(tester);
      await theWindowsLogIsKept(tester);
      await iOfferTheIdeaForDiscussion(tester, 'Let the board show who is at work');
      await iTurnTheDiscussionsStartAway(tester);
      await theWindowsLogSaysNothingOf(tester, 'was refused');
      await noNoticeSaysAStartWasRefused(tester);
    });
  });
}
