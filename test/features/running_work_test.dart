// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_the_running_work.dart';
import './step/the_work_has_stopped.dart';
import './step/there_is_a_tab_for.dart';
import './step/there_is_no_tab_for.dart';
import './step/i_choose_the_tab_of.dart';
import './step/the_bar_says.dart';
import './step/i_press_ctrl_and_page_down.dart';
import './step/the_tab_of_is_not_chosen.dart';
import './step/the_session_was_sent_nothing.dart';
import './step/i_press_ctrl_and_page_up.dart';
import './step/the_tab_of_is_chosen.dart';
import './step/sessions_are_open.dart';
import './step/the_session_on_screen_is.dart';
import './step/the_first_session_was_left.dart';
import './step/the_work_was_never_stopped.dart';
import './step/the_session_is_on_screen.dart';
import './step/there_is_no_field_to_type_into.dart';
import './step/the_terminal_session_of_has_ended.dart';
import './step/it_says.dart';
import './step/no_session_is_open.dart';
import './step/i_open_a_new_terminal_from_the_tab.dart';
import './step/the_session_ends_with.dart';
import './step/seconds_pass.dart';
import './step/it_does_not_say.dart';
import './step/i_go_to_the_list_of_work.dart';
import './step/i_open_the_tile.dart';
import './step/the_tile_says.dart';
import './step/the_tile_of_draws_no_console.dart';
import './step/the_row_of_offers.dart';
import './step/i_open_a_new_terminal_from_the_row_of.dart';
import './step/i_watch_another_machine_called.dart';
import './step/the_tab_offers_to_read_its_log.dart';
import './step/work_is_blocked_reaching.dart';
import './step/i_answer_in_needs_you.dart';
import './step/the_view_shown_is_what_needs_a_person.dart';
import './step/the_work_runs_unattended.dart';
import './step/the_agent_of_writes.dart';
import './step/the_console_says.dart';
import './step/the_console_has_a_switch_to_follow_it.dart';
import './step/i_choose_from_the_menu_of_the_tile.dart';
import './step/i_follow_its_log_again.dart';
import './step/the_work_has_used_tokens.dart';
import './step/the_fact_of_says.dart';
import './step/what_used_was_not_asked_for.dart';

void main() {
  group('''A tab per running agent, the one place terminals are''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await iGoToTheRunningWork(tester);
    }

    testWidgets('''every running agent has a tab, and stopped work has none''', (tester) async {
      await bddSetUp(tester);
      await theWorkHasStopped(tester, 'porelo-billing-audit');
      await thereIsATabFor(tester, 'porelo-checkout-shell');
      await thereIsATabFor(tester, 'porelo-billing-shell');
      await thereIsNoTabFor(tester, 'porelo-billing-audit');
    });
    testWidgets('''the bar under the tabs names the work, where it runs and its way of working''', (tester) async {
      await bddSetUp(tester);
      await iChooseTheTabOf(tester, 'porelo-billing-shell');
      await theBarSays(tester, 'porelo-billing-shell');
      await theBarSays(tester, 'billing');
      await theBarSays(tester, 'on this machine');
      await theBarSays(tester, 'In a terminal');
    });
    testWidgets('''Ctrl and the page keys go to the next agent and back, before a terminal takes them''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await iChooseTheTabOf(tester, 'porelo-billing-shell');
      await iPressCtrlAndPageDown(tester);
      await theTabOfIsNotChosen(tester, 'porelo-billing-shell');
      await theSessionWasSentNothing(tester);
      await iPressCtrlAndPageUp(tester);
      await theTabOfIsChosen(tester, 'porelo-billing-shell');
    });
    testWidgets('''changing the tab leaves the session, and one stays open''', (tester) async {
      await bddSetUp(tester);
      await iChooseTheTabOf(tester, 'porelo-billing-audit');
      await sessionsAreOpen(tester, 1);
      await iPressCtrlAndPageDown(tester);
      await sessionsAreOpen(tester, 1);
      await theSessionOnScreenIs(tester, 'porelo-billing-shell');
      await theFirstSessionWasLeft(tester);
      await theWorkWasNeverStopped(tester);
    });
    testWidgets('''an agent in a terminal has the terminal and no input line of its own''', (tester) async {
      await bddSetUp(tester);
      await iChooseTheTabOf(tester, 'porelo-billing-shell');
      await theSessionIsOnScreen(tester);
      await thereIsNoFieldToTypeInto(tester);
    });
    testWidgets('''a running task whose terminal has ended keeps its tab, says so, and offers a new one''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theTerminalSessionOfHasEnded(tester, 'porelo-billing-shell');
      await iChooseTheTabOf(tester, 'porelo-billing-shell');
      await itSays(tester, 'No terminal is open in it');
      await noSessionIsOpen(tester);
      await iOpenANewTerminalFromTheTab(tester);
      await sessionsAreOpen(tester, 1);
      await theSessionOnScreenIs(tester, 'porelo-billing-shell');
    });
    testWidgets('''a terminal the machine would not open keeps what was said, whatever a look says after''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await iChooseTheTabOf(tester, 'porelo-billing-shell');
      await theSessionEndsWith(tester, 69);
      await theTerminalSessionOfHasEnded(tester, 'porelo-billing-shell');
      await secondsPass(tester, 60);
      await itSays(tester, 'The machine would not open a session here');
      await itDoesNotSay(tester, 'No terminal is open in it');
    });
    testWidgets('''the row of a running task whose terminal has ended says the same, and draws no console for it''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theTerminalSessionOfHasEnded(tester, 'porelo-billing-shell');
      await iGoToTheListOfWork(tester);
      await iOpenTheTile(tester, 'porelo-billing-shell');
      await theTileSays(tester, 'porelo-billing-shell', 'No terminal is open in it');
      await theTileOfDrawsNoConsole(tester, 'porelo-billing-shell');
      await theRowOfOffers(tester, 'porelo-billing-shell', 'Open a new terminal');
      await iOpenANewTerminalFromTheRowOf(tester, 'porelo-billing-shell');
      await theTabOfIsChosen(tester, 'porelo-billing-shell');
      await sessionsAreOpen(tester, 1);
    });
    testWidgets('''where no terminal can be opened, the tab and the row offer the log''', (tester) async {
      await bddSetUp(tester);
      await iWatchAnotherMachineCalled(tester, 'elsewhere');
      await iGoToTheRunningWork(tester);
      await iChooseTheTabOf(tester, 'porelo-shared-shell');
      await itSays(tester, 'nowhere to run');
      await theTabOffersToReadItsLog(tester);
      await iGoToTheListOfWork(tester);
      await iOpenTheTile(tester, 'porelo-shared-shell');
      await theRowOfOffers(tester, 'porelo-shared-shell', 'Read its log');
    });
    testWidgets('''work waiting on a person says so under the bar and leads to Needs you''', (tester) async {
      await bddSetUp(tester);
      await workIsBlockedReaching(tester, 'api.example.test:443');
      await iChooseTheTabOf(tester, 'porelo-checkout-shell');
      await itSays(tester, 'Waits on you: asks to reach api.example.test');
      await itDoesNotSay(tester, 'Let it through');
      await iAnswerInNeedsYou(tester);
      await theViewShownIsWhatNeedsAPerson(tester);
    });
    testWidgets('''an unattended agent shows its log in the console, with a switch to follow it''', (tester) async {
      await bddSetUp(tester);
      await theWorkRunsUnattended(tester, 'porelo-billing-shell');
      await iChooseTheTabOf(tester, 'porelo-billing-shell');
      await theAgentOfWrites(tester, 'porelo-billing-shell', 'reading the contracts');
      await secondsPass(tester, 1);
      await theConsoleSays(tester, 'reading the contracts');
      await theConsoleHasASwitchToFollowIt(tester);
      await noSessionIsOpen(tester);
    });
    testWidgets('''an unattended agent can still be worked in by hand, and its log followed again''', (tester) async {
      await bddSetUp(tester);
      await theWorkRunsUnattended(tester, 'porelo-billing-shell');
      await iGoToTheListOfWork(tester);
      await iChooseFromTheMenuOfTheTile(tester, 'Work in it by hand', 'porelo-billing-shell');
      await theSessionOnScreenIs(tester, 'porelo-billing-shell');
      await iFollowItsLogAgain(tester);
      await noSessionIsOpen(tester);
      await theConsoleHasASwitchToFollowIt(tester);
    });
    testWidgets('''an unfolded row says what its work used, as its machine reads it''', (tester) async {
      await bddSetUp(tester);
      await theWorkHasUsedTokens(tester, 'porelo-billing-shell', 184000);
      await iGoToTheListOfWork(tester);
      await iOpenTheTile(tester, 'porelo-billing-shell');
      await theFactOfSays(tester, 'tokens', 'porelo-billing-shell', '184 k');
    });
    testWidgets('''a machine older than what work used says nothing of it, and is asked only when unfolded''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await iGoToTheListOfWork(tester);
      await whatUsedWasNotAskedFor(tester, 'porelo-billing-shell');
      await iOpenTheTile(tester, 'porelo-billing-shell');
      await theFactOfSays(tester, 'tokens', 'porelo-billing-shell', 'not said');
    });
  });
}
