// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_what_needs_a_person.dart';
import './step/the_view_shown_is_what_needs_a_person.dart';
import './step/the_first_tile_is.dart';
import './step/no_tile_is_shown_for.dart';
import './step/other_work_is_blocked_reaching.dart';
import './step/work_is_blocked_reaching.dart';
import './step/the_tile_says.dart';
import './step/i_let_it_through_from_its_tile.dart';
import './step/the_answer_sent_was.dart';
import './step/the_answer_comes_back.dart';
import './step/i_put_away_what_the_tile_says.dart';
import './step/the_question_runs_out.dart';
import './step/i_watch_another_machine_called.dart';
import './step/work_on_is_blocked_reaching.dart';
import './step/the_tunnel_drops.dart';
import './step/a_machine_notice_says.dart';
import './step/no_tile_says.dart';
import './step/enough_time_passes_for_another_try.dart';
import './step/no_machine_notice_says.dart';
import './step/porelo_is_not_installed_on_this_computer.dart';
import './step/i_open_the_command_finder.dart';
import './step/the_command_finder_is_open.dart';
import './step/the_machine_is_the_same_node.dart';
import './step/the_same_question_arrives_through_both.dart';
import './step/tile_asks_to_reach.dart';
import './step/i_choose_from_the_menu_of_the_tile.dart';
import './step/what_to_ask_it_says.dart';
import './step/i_review_the_work_from_its_tile.dart';
import './step/i_open_the_waiting_push.dart';
import './step/the_review_shows_the_file.dart';
import './step/work_is_blocked_reaching_with_minutes_left.dart';
import './step/work_is_blocked_reaching_with_no_deadline.dart';
import './step/work_is_blocked_reaching_past_its_deadline.dart';
import './step/the_tile_does_not_say.dart';
import './step/other_work_is_blocked_reaching_with_minutes_left.dart';
import './step/i_open_the_menu_of_the_tile.dart';
import './step/the_menu_offers_as_unavailable_because.dart';
import './step/was_stopped_on_the_machine.dart';
import './step/nothing_was_stopped_on_this_machine.dart';
import './step/the_tile_is_headed.dart';
import './step/i_mark_the_notice_about_as_seen.dart';
import './step/nothing_needs_me.dart';
import './step/the_machine_dropped_questions_unseen.dart';
import './step/it_says.dart';
import './step/i_mark_the_dropped_questions_seen.dart';
import './step/it_does_not_say.dart';
import './step/the_agent_of_ended_with_the_providers.dart';
import './step/the_agent_of_finished.dart';
import './step/the_messages_of_wait_because.dart';

void main() {
  group('''What needs a person on every machine, without going anywhere''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await iGoToWhatNeedsAPerson(tester);
    }

    testWidgets('''what needs a person is one step from the work the window opens on''', (tester) async {
      await bddSetUp(tester);
      await theViewShownIsWhatNeedsAPerson(tester);
    });
    testWidgets('''work that needs nobody is not on what needs a person''', (tester) async {
      await bddSetUp(tester);
      await theFirstTileIs(tester, 'porelo-checkout-migrate');
      await noTileIsShownFor(tester, 'porelo-billing-shell');
      await noTileIsShownFor(tester, 'porelo-checkout-shell');
    });
    testWidgets('''a question waiting for an answer is above work that is merely running''', (tester) async {
      await bddSetUp(tester);
      await otherWorkIsBlockedReaching(tester, 'files.example.test:22');
      await theFirstTileIs(tester, 'porelo-billing-shell');
    });
    testWidgets('''a question says how long it has been blocked, not a deadline nobody sent''', (tester) async {
      await bddSetUp(tester);
      await workIsBlockedReaching(tester, 'api.example.test:443');
      await theTileSays(tester, 'porelo-checkout-shell', 'blocked for');
      await theTileSays(tester, 'porelo-checkout-shell', 'does not say when');
    });
    testWidgets('''a question is answered from its tile, without leaving the view''', (tester) async {
      await bddSetUp(tester);
      await workIsBlockedReaching(tester, 'api.example.test:443');
      await iLetItThroughFromItsTile(tester);
      await theAnswerSentWas(tester, 'allow');
      await theViewShownIsWhatNeedsAPerson(tester);
    });
    testWidgets('''a question let through stays with its answer until it is put away''', (tester) async {
      await bddSetUp(tester);
      await workIsBlockedReaching(tester, 'api.example.test:443');
      await iLetItThroughFromItsTile(tester);
      await theAnswerComesBack(tester);
      await theTileSays(tester, 'porelo-checkout-shell', 'is now reachable');
      await iPutAwayWhatTheTileSays(tester, 'porelo-checkout-shell');
      await noTileIsShownFor(tester, 'porelo-checkout-shell');
    });
    testWidgets('''a question that ran out stays, saying so, until it is put away''', (tester) async {
      await bddSetUp(tester);
      await workIsBlockedReaching(tester, 'api.example.test:443');
      await theQuestionRunsOut(tester);
      await theTileSays(tester, 'porelo-checkout-shell', 'ran out');
      await iPutAwayWhatTheTileSays(tester, 'porelo-checkout-shell');
      await noTileIsShownFor(tester, 'porelo-checkout-shell');
    });
    testWidgets('''a question on another machine is in the same list, with its machine on it''', (tester) async {
      await bddSetUp(tester);
      await iWatchAnotherMachineCalled(tester, 'elsewhere');
      await workOnIsBlockedReaching(tester, 'elsewhere', 'api.example.test:443');
      await theTileSays(tester, 'porelo-shared-shell', 'elsewhere');
    });
    testWidgets('''a machine that cannot be reached says so above the tiles, not as one''', (tester) async {
      await bddSetUp(tester);
      await theTunnelDrops(tester);
      await aMachineNoticeSays(tester, 'cannot be reached');
      await noTileSays(tester, 'cannot be reached');
      await enoughTimePassesForAnotherTry(tester);
      await noMachineNoticeSays(tester, 'cannot be reached');
    });
    testWidgets('''this computer, with no Porelo installed, is not said to be unreachable''', (tester) async {
      await bddSetUp(tester);
      await poreloIsNotInstalledOnThisComputer(tester);
      await theTunnelDrops(tester);
      await noMachineNoticeSays(tester, 'cannot be reached');
      await enoughTimePassesForAnotherTry(tester);
      await noMachineNoticeSays(tester, 'cannot be reached');
    }, tags: ['linux']);
    testWidgets('''the keyboard works the moment the window opens''', (tester) async {
      await bddSetUp(tester);
      await iOpenTheCommandFinder(tester);
      await theCommandFinderIsOpen(tester);
    });
    testWidgets('''one node reached two ways asks each question once''', (tester) async {
      await bddSetUp(tester);
      await theMachineIsTheSameNode(tester, 'elsewhere');
      await iWatchAnotherMachineCalled(tester, 'elsewhere');
      await theSameQuestionArrivesThroughBoth(tester);
      await tileAsksToReach(tester, 1, 'api.example.test');
    });
    testWidgets('''a finished run is continued from its tile, without going to its project''', (tester) async {
      await bddSetUp(tester);
      await iChooseFromTheMenuOfTheTile(tester, 'Continue this work with a new prompt', 'porelo-checkout-migrate');
      await whatToAskItSays(tester, 'Fix the rounding in Money.pennies');
    });
    testWidgets('''work waiting at the gate is reviewed from its tile, over the view''', (tester) async {
      await bddSetUp(tester);
      await iReviewTheWorkFromItsTile(tester, 'porelo-checkout-migrate');
      await iOpenTheWaitingPush(tester);
      await theReviewShowsTheFile(tester, 'lib/money.dart');
    });
    testWidgets('''a question with a deadline says how long is left''', (tester) async {
      await bddSetUp(tester);
      await workIsBlockedReachingWithMinutesLeft(tester, 'api.example.test:443', 3);
      await theTileSays(tester, 'porelo-checkout-shell', '3 minutes left');
    });
    testWidgets('''a question that never runs out says so, rather than counting down''', (tester) async {
      await bddSetUp(tester);
      await workIsBlockedReachingWithNoDeadline(tester, 'api.example.test:443');
      await theTileSays(tester, 'porelo-checkout-shell', 'does not run out');
    });
    testWidgets('''a question past its deadline says its time is up, not how long is left''', (tester) async {
      await bddSetUp(tester);
      await workIsBlockedReachingPastItsDeadline(tester, 'api.example.test:443');
      await theTileSays(tester, 'porelo-checkout-shell', 'out of time');
      await theTileDoesNotSay(tester, 'porelo-checkout-shell', 'left');
    });
    testWidgets('''the question nearest its deadline comes first''', (tester) async {
      await bddSetUp(tester);
      await workIsBlockedReachingWithMinutesLeft(tester, 'api.example.test:443', 2);
      await otherWorkIsBlockedReachingWithMinutesLeft(tester, 'files.example.test:22', 10);
      await theFirstTileIs(tester, 'porelo-checkout-shell');
    });
    testWidgets('''work reached through a forwarded socket offers no session, and says why''', (tester) async {
      await bddSetUp(tester);
      await iWatchAnotherMachineCalled(tester, 'elsewhere');
      await workOnIsBlockedReaching(tester, 'elsewhere', 'api.example.test:443');
      await iOpenTheMenuOfTheTile(tester, 'porelo-shared-shell');
      await theMenuOffersAsUnavailableBecause(tester, 'Work in it by hand', 'forwarded');
    });
    testWidgets('''stopping from another machine's tile stops it there''', (tester) async {
      await bddSetUp(tester);
      await iWatchAnotherMachineCalled(tester, 'elsewhere');
      await workOnIsBlockedReaching(tester, 'elsewhere', 'api.example.test:443');
      await iChooseFromTheMenuOfTheTile(tester, 'Stop it, keeping its workspace', 'porelo-shared-shell');
      await wasStoppedOnTheMachine(tester, 'porelo-shared-shell', 'elsewhere');
      await nothingWasStoppedOnThisMachine(tester);
    });
    testWidgets('''every tile is headed by the machine its work is on''', (tester) async {
      await bddSetUp(tester);
      await iWatchAnotherMachineCalled(tester, 'elsewhere');
      await workIsBlockedReaching(tester, 'api.example.test:443');
      await workOnIsBlockedReaching(tester, 'elsewhere', 'files.example.test:22');
      await theTileIsHeaded(tester, 'porelo-shared-shell', 'elsewhere');
      await theTileIsHeaded(tester, 'porelo-checkout-shell', 'this machine');
    });
    testWidgets('''a silent machine can be marked as seen, until it has answered again''', (tester) async {
      await bddSetUp(tester);
      await theTunnelDrops(tester);
      await iMarkTheNoticeAboutAsSeen(tester, 'this machine');
      await noMachineNoticeSays(tester, 'cannot be reached');
      await nothingNeedsMe(tester);
      await enoughTimePassesForAnotherTry(tester);
      await theTunnelDrops(tester);
      await aMachineNoticeSays(tester, 'cannot be reached');
      await enoughTimePassesForAnotherTry(tester);
      await noMachineNoticeSays(tester, 'cannot be reached');
    });
    testWidgets('''questions a machine dropped unseen are said, until marked seen''', (tester) async {
      await bddSetUp(tester);
      await theMachineDroppedQuestionsUnseen(tester, 2);
      await itSays(tester, 'dropped 2 questions about a blocked connection before it was seen');
      await itSays(tester, 'A dropped question is not asked again');
      await iMarkTheDroppedQuestionsSeen(tester);
      await itDoesNotSay(tester, 'dropped 2 questions');
    });
    testWidgets('''work whose agent was refused by its provider needs you, in the provider's words''', (tester) async {
      await bddSetUp(tester);
      await theAgentOfEndedWithTheProviders(tester, 'porelo-checkout-shell', 402, 'This request requires more credits');
      await theFirstTileIs(tester, 'porelo-checkout-shell');
      await itSays(tester, 'The provider refused it: no credits left (402): This request requires more credits');
      await itDoesNotSay(tester, 'Working');
    });
    testWidgets('''work whose agent finished needs nobody''', (tester) async {
      await bddSetUp(tester);
      await theAgentOfFinished(tester, 'porelo-checkout-shell');
      await noTileIsShownFor(tester, 'porelo-checkout-shell');
    });
    testWidgets('''messages that wait because the vault is locked are said, with the projects they hold up''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theMessagesOfWaitBecause(
        tester,
        'checkout',
        'messages wait: the vault is locked, so no conversation can be read or written: porelo vault unlock lets them go on',
      );
      await itSays(tester, 'Messages wait on');
      await itSays(tester, 'the vault is locked, so no conversation can be read or written');
      await itSays(tester, 'Held up: checkout');
    });
  });
}
