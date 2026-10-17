// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_the_work.dart';
import './step/the_work_is_idle.dart';
import './step/the_work_is_waiting_on.dart';
import './step/the_tile_is_marked_as_a_guess.dart';
import './step/the_tile_is_not_marked_as_a_guess.dart';
import './step/the_work_runs_brokered_to.dart';
import './step/the_tile_says.dart';
import './step/the_tile_does_not_say.dart';
import './step/i_select_the_work.dart';
import './step/i_open_the_selection.dart';
import './step/the_detail_for_is_shown.dart';
import './step/it_says.dart';
import './step/the_tile_is_headed_by_its_work.dart';
import './step/the_tile_shows_the_state.dart';
import './step/the_work_has_stopped.dart';
import './step/i_select_the_project.dart';
import './step/the_work_cannot_be_seen.dart';
import './step/i_work_in_by_hand_from_its_tile.dart';
import './step/the_session_runs.dart';
import './step/i_leave_the_session.dart';
import './step/the_view_shown_is_the_work.dart';
import './step/the_name_on_the_tile_can_be_copied.dart';
import './step/i_open_the_menu_of_the_tile.dart';
import './step/the_menu_offers.dart';
import './step/i_click_the_tile_with_the_right_button.dart';
import './step/i_choose_from_the_menu_of_the_tile.dart';
import './step/was_started_again.dart';
import './step/starting_it_again_will_be_refused_because_the_vault_is_locked.dart';
import './step/starting_it_again_will_fail_with_exit_code_saying.dart';
import './step/the_machine_says_starting_needs_the_vault_unlocked.dart';
import './step/the_menu_offers_as_unavailable_because.dart';
import './step/the_machine_says_was_started_before_the_machine_restarted.dart';
import './step/the_machine_says_has_a_name_from_before_one_container_per_task.dart';
import './step/the_project_has_the_repositories.dart';
import './step/the_work_works_in_the_repository.dart';
import './step/it_was_started_again_in_the_repository.dart';
import './step/it_was_started_again_in_no_repository.dart';
import './step/the_machine_says_a_restart_of_its_machine_took_down.dart';
import './step/a_terminal_runs_on_the_machine.dart';
import './step/no_tile_says.dart';
import './step/the_menu_does_not_offer.dart';
import './step/the_machine_says_a_restart_took_down_and_its_tokens_wait_in_the_locked_vault.dart';
import './step/the_work_runs_unattended.dart';
import './step/the_tile_of_shows.dart';
import './step/the_agent_of_writes.dart';
import './step/the_tile_of_does_not_show_yet.dart';
import './step/seconds_pass.dart';
import './step/its_tail_was_asked_for_from_its_last_lines_formatted.dart';
import './step/i_enlarge_the_console_of.dart';
import './step/the_view_shown_is.dart';
import './step/the_terminal_of_shows.dart';
import './step/the_screen_of_was_asked_for_at_most_times.dart';
import './step/sessions_are_open.dart';

void main() {
  group('''Work in its machine's area, as tiles that carry their own actions''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await iGoToTheWork(tester);
    }

    testWidgets('''a quiet task is marked as a guess, and a known state never is''', (tester) async {
      await bddSetUp(tester);
      await theWorkIsIdle(tester, 'porelo-checkout-shell');
      await theWorkIsWaitingOn(tester, 'porelo-billing-shell', 'api.example.test:443');
      await theTileIsMarkedAsAGuess(tester, 'porelo-checkout-shell');
      await theTileIsNotMarkedAsAGuess(tester, 'porelo-billing-shell');
    });
    testWidgets('''work says which provider its agent was brokered to, and nothing where none is recorded''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theWorkRunsBrokeredTo(tester, 'porelo-checkout-shell', 'an-agent', 'github-copilot');
      await theWorkRunsBrokeredTo(tester, 'porelo-billing-shell', 'an-agent', '');
      await theTileSays(tester, 'porelo-checkout-shell', 'an-agent via github-copilot');
      await theTileSays(tester, 'porelo-billing-shell', 'an-agent');
      await theTileDoesNotSay(tester, 'porelo-billing-shell', 'via');
      await iSelectTheWork(tester, 'porelo-checkout-shell');
      await iOpenTheSelection(tester);
      await theDetailForIsShown(tester, 'porelo-checkout-shell');
      await itSays(tester, 'github-copilot');
    });
    testWidgets('''a tile is headed by its work, and its state is marked by colour and shape''', (tester) async {
      await bddSetUp(tester);
      await theWorkIsWaitingOn(tester, 'porelo-billing-shell', 'api.example.test:443');
      await theTileIsHeadedByItsWork(tester, 'porelo-billing-shell');
      await theTileShowsTheState(tester, 'porelo-billing-shell', 'question');
      await theWorkHasStopped(tester, 'porelo-checkout-shell');
      await iSelectTheProject(tester, 'checkout');
      await theTileIsHeadedByItsWork(tester, 'porelo-checkout-shell');
      await theTileShowsTheState(tester, 'porelo-checkout-shell', 'stopped');
    });
    testWidgets('''work nothing can see is never drawn as quiet''', (tester) async {
      await bddSetUp(tester);
      await theWorkCannotBeSeen(tester, 'porelo-checkout-shell');
      await theTileSays(tester, 'porelo-checkout-shell', 'Running');
      await theTileIsNotMarkedAsAGuess(tester, 'porelo-checkout-shell');
    });
    testWidgets('''work is opened by hand from the work page, and leaving it comes back there''', (tester) async {
      await bddSetUp(tester);
      await iWorkInByHandFromItsTile(tester, 'porelo-checkout-shell');
      await theSessionRuns(tester, 'porelo task attach porelo-checkout-shell');
      await iLeaveTheSession(tester);
      await theViewShownIsTheWork(tester);
    });
    testWidgets('''the name on a tile can be selected and copied''', (tester) async {
      await bddSetUp(tester);
      await theNameOnTheTileCanBeCopied(tester, 'porelo-checkout-shell');
    });
    testWidgets('''a tile offers what its work can be told to do, from its menu''', (tester) async {
      await bddSetUp(tester);
      await iOpenTheMenuOfTheTile(tester, 'porelo-checkout-shell');
      await theMenuOffers(tester, 'Work in it by hand');
    });
    testWidgets('''clicking a tile with the right button opens the same menu''', (tester) async {
      await bddSetUp(tester);
      await iClickTheTileWithTheRightButton(tester, 'porelo-checkout-shell');
      await theMenuOffers(tester, 'Work in it by hand');
    });
    testWidgets('''work started again from its tile says what came of it, on the tile''', (tester) async {
      await bddSetUp(tester);
      await theWorkHasStopped(tester, 'porelo-checkout-shell');
      await iSelectTheProject(tester, 'checkout');
      await iChooseFromTheMenuOfTheTile(tester, 'Start it again', 'porelo-checkout-shell');
      await wasStartedAgain(tester, 'porelo-checkout-shell');
      await theTileSays(tester, 'porelo-checkout-shell', 'is running again');
    });
    testWidgets('''a start the machine refused when pressed says so on the tile''', (tester) async {
      await bddSetUp(tester);
      await theWorkHasStopped(tester, 'porelo-checkout-shell');
      await startingItAgainWillBeRefusedBecauseTheVaultIsLocked(tester);
      await iSelectTheProject(tester, 'checkout');
      await iChooseFromTheMenuOfTheTile(tester, 'Start it again', 'porelo-checkout-shell');
      await theTileSays(tester, 'porelo-checkout-shell', 'the vault is locked');
    });
    testWidgets('''a start that failed with an exit code says what the machine printed, on the tile''', (tester) async {
      await bddSetUp(tester);
      await theWorkHasStopped(tester, 'porelo-checkout-shell');
      await startingItAgainWillFailWithExitCodeSaying(tester, 70, 'Several agents are installed');
      await iSelectTheProject(tester, 'checkout');
      await iChooseFromTheMenuOfTheTile(tester, 'Start it again', 'porelo-checkout-shell');
      await theTileSays(tester, 'porelo-checkout-shell', 'Several agents are installed');
    });
    testWidgets('''a start the machine would refuse is unavailable on the tile, with its reason''', (tester) async {
      await bddSetUp(tester);
      await theWorkHasStopped(tester, 'porelo-checkout-shell');
      await theMachineSaysStartingNeedsTheVaultUnlocked(tester, 'porelo-checkout-shell');
      await iSelectTheProject(tester, 'checkout');
      await iOpenTheMenuOfTheTile(tester, 'porelo-checkout-shell');
      await theMenuOffersAsUnavailableBecause(tester, 'Start it again', 'vault is locked');
    });
    testWidgets('''work started before its machine restarted can only be recovered, and says how''', (tester) async {
      await bddSetUp(tester);
      await theWorkHasStopped(tester, 'porelo-checkout-shell');
      await theMachineSaysWasStartedBeforeTheMachineRestarted(tester, 'porelo-checkout-shell');
      await iSelectTheProject(tester, 'checkout');
      await iOpenTheMenuOfTheTile(tester, 'porelo-checkout-shell');
      await theMenuOffersAsUnavailableBecause(tester, 'Start it again', 'podman cp porelo-checkout-shell:/workspace');
    });
    testWidgets('''a container named from before one per task can only be removed''', (tester) async {
      await bddSetUp(tester);
      await theWorkHasStopped(tester, 'porelo-checkout-shell');
      await theMachineSaysHasANameFromBeforeOneContainerPerTask(tester, 'porelo-checkout-shell');
      await iSelectTheProject(tester, 'checkout');
      await iOpenTheMenuOfTheTile(tester, 'porelo-checkout-shell');
      await theMenuOffersAsUnavailableBecause(tester, 'Start it again', 'can only be removed');
    });
    testWidgets('''a tile names the repository its work is in, once there is more than one''', (tester) async {
      await bddSetUp(tester);
      await theProjectHasTheRepositories(tester, 'checkout', 'checkout, payments-api');
      await theWorkWorksInTheRepository(tester, 'porelo-checkout-shell', 'payments-api');
      await theTileSays(tester, 'porelo-checkout-shell', 'in payments-api');
    });
    testWidgets('''work started again starts in the repository it worked in''', (tester) async {
      await bddSetUp(tester);
      await theProjectHasTheRepositories(tester, 'checkout', 'checkout, payments-api');
      await theWorkWorksInTheRepository(tester, 'porelo-checkout-shell', 'payments-api');
      await theWorkHasStopped(tester, 'porelo-checkout-shell');
      await iSelectTheProject(tester, 'checkout');
      await iChooseFromTheMenuOfTheTile(tester, 'Start it again', 'porelo-checkout-shell');
      await itWasStartedAgainInTheRepository(tester, 'payments-api');
    });
    testWidgets('''work that names no repository is in the project's own''', (tester) async {
      await bddSetUp(tester);
      await theProjectHasTheRepositories(tester, 'checkout', 'checkout, payments-api');
      await theWorkHasStopped(tester, 'porelo-checkout-shell');
      await iSelectTheProject(tester, 'checkout');
      await theTileSays(tester, 'porelo-checkout-shell', 'in checkout');
      await iChooseFromTheMenuOfTheTile(tester, 'Start it again', 'porelo-checkout-shell');
      await itWasStartedAgainInTheRepository(tester, 'checkout');
    });
    testWidgets('''a machine that names no repositories is started again in none''', (tester) async {
      await bddSetUp(tester);
      await theWorkHasStopped(tester, 'porelo-checkout-shell');
      await iSelectTheProject(tester, 'checkout');
      await iChooseFromTheMenuOfTheTile(tester, 'Start it again', 'porelo-checkout-shell');
      await itWasStartedAgainInNoRepository(tester);
    });
    testWidgets('''work a restart took down says why on its tile, and can be started again''', (tester) async {
      await bddSetUp(tester);
      await theWorkHasStopped(tester, 'porelo-checkout-shell');
      await theMachineSaysARestartOfItsMachineTookDown(tester, 'porelo-checkout-shell');
      await iSelectTheProject(tester, 'checkout');
      await theTileSays(tester, 'porelo-checkout-shell', 'the machine restarted; starting it brings it back whole');
      await iOpenTheMenuOfTheTile(tester, 'porelo-checkout-shell');
      await theMenuOffers(tester, 'Start it again');
    });
    testWidgets('''work a restart took down, started again, says what was restored''', (tester) async {
      await bddSetUp(tester);
      await theWorkHasStopped(tester, 'porelo-checkout-shell');
      await theMachineSaysARestartOfItsMachineTookDown(tester, 'porelo-checkout-shell');
      await iSelectTheProject(tester, 'checkout');
      await iChooseFromTheMenuOfTheTile(tester, 'Start it again', 'porelo-checkout-shell');
      await theTileSays(tester, 'porelo-checkout-shell', 'its records, its egress and its tokens were restored');
    });
    testWidgets('''work whose start needs the vault unlocked offers to unlock it''', (tester) async {
      await bddSetUp(tester);
      await theWorkHasStopped(tester, 'porelo-checkout-shell');
      await theMachineSaysStartingNeedsTheVaultUnlocked(tester, 'porelo-checkout-shell');
      await iSelectTheProject(tester, 'checkout');
      await iChooseFromTheMenuOfTheTile(tester, 'Unlock the vault, so this can start', 'porelo-checkout-shell');
      await aTerminalRunsOnTheMachine(tester, 'porelo vault unlock');
    });
    testWidgets('''work that can simply be started again says nothing about a restart''', (tester) async {
      await bddSetUp(tester);
      await theWorkHasStopped(tester, 'porelo-checkout-shell');
      await iSelectTheProject(tester, 'checkout');
      await noTileSays(tester, 'restarted');
      await iOpenTheMenuOfTheTile(tester, 'porelo-checkout-shell');
      await theMenuDoesNotOffer(tester, 'Unlock the vault, so this can start');
    });
    testWidgets('''work a restart took down says why in its detail too''', (tester) async {
      await bddSetUp(tester);
      await theWorkHasStopped(tester, 'porelo-checkout-shell');
      await theMachineSaysARestartOfItsMachineTookDown(tester, 'porelo-checkout-shell');
      await iSelectTheProject(tester, 'checkout');
      await iSelectTheWork(tester, 'porelo-checkout-shell');
      await iOpenTheSelection(tester);
      await theDetailForIsShown(tester, 'porelo-checkout-shell');
      await itSays(tester, 'Why it is down');
      await itSays(tester, 'the machine restarted; starting it brings it back whole');
    });
    testWidgets('''work a restart took down while the vault is locked says why, and offers to unlock''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theWorkHasStopped(tester, 'porelo-checkout-shell');
      await theMachineSaysARestartTookDownAndItsTokensWaitInTheLockedVault(tester, 'porelo-checkout-shell');
      await iSelectTheProject(tester, 'checkout');
      await theTileSays(tester, 'porelo-checkout-shell', 'the machine restarted; starting it brings it back whole');
      await iOpenTheMenuOfTheTile(tester, 'porelo-checkout-shell');
      await theMenuOffersAsUnavailableBecause(tester, 'Start it again', 'vault is locked');
      await theMenuOffers(tester, 'Unlock the vault, so this can start');
    });
    testWidgets('''a tile shows the newest lines its agent writes, drawn only now and then''', (tester) async {
      await bddSetUp(tester);
      await theWorkRunsUnattended(tester, 'porelo-billing-shell');
      await theTileOfShows(tester, 'porelo-billing-shell', 'Nothing written yet.');
      await theAgentOfWrites(tester, 'porelo-billing-shell', 'reading the contracts');
      await theTileOfShows(tester, 'porelo-billing-shell', 'reading the contracts');
      await theAgentOfWrites(tester, 'porelo-billing-shell', '[read] doc/Backend-API.md');
      await theTileOfDoesNotShowYet(tester, 'porelo-billing-shell', '[read] doc/Backend-API.md');
      await secondsPass(tester, 3);
      await theTileOfShows(tester, 'porelo-billing-shell', '[read] doc/Backend-API.md');
      await itsTailWasAskedForFromItsLastLinesFormatted(tester, 20);
    });
    testWidgets('''a tile's console is enlarged to the right side, following, and made small again''', (tester) async {
      await bddSetUp(tester);
      await theWorkRunsUnattended(tester, 'porelo-billing-shell');
      await iEnlargeTheConsoleOf(tester, 'porelo-billing-shell');
      await theViewShownIs(tester, 'porelo-billing-shell · what its agent writes');
    });
    testWidgets('''a tile of work in a terminal says where its agent's lines are, and reads no log''', (tester) async {
      await bddSetUp(tester);
      await theTileOfShows(tester, 'porelo-billing-shell', 'Its agent works in its terminal - open it to see.');
    });
    testWidgets('''a tile of work in a terminal shows what its session shows, asked only every few seconds''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theTerminalOfShows(tester, 'porelo-billing-shell', 'agent> make test');
      await theTileOfShows(tester, 'porelo-billing-shell', 'Its agent works in its terminal - open it to see.');
      await secondsPass(tester, 3);
      await theTileOfShows(tester, 'porelo-billing-shell', 'agent> make test');
      await secondsPass(tester, 9);
      await theScreenOfWasAskedForAtMostTimes(tester, 'porelo-billing-shell', 5);
    });
    testWidgets('''enlarging the console of work in a terminal opens its session''', (tester) async {
      await bddSetUp(tester);
      await theTerminalOfShows(tester, 'porelo-billing-shell', 'agent> make test');
      await theTileOfShows(tester, 'porelo-billing-shell', 'Its agent works in its terminal - open it to see.');
      await secondsPass(tester, 3);
      await iEnlargeTheConsoleOf(tester, 'porelo-billing-shell');
      await sessionsAreOpen(tester, 1);
    });
  });
}
