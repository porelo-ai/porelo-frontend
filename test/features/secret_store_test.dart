// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_the_work.dart';
import './step/i_show_the_vault.dart';
import './step/it_lists_the_credential.dart';
import './step/it_says.dart';
import './step/nothing_was_done_to_the_store.dart';
import './step/two_running_tasks_still_hold_what_they_read.dart';
import './step/i_shut_the_store.dart';
import './step/the_store_was_already_shut.dart';
import './step/the_store_is_shut.dart';
import './step/it_does_not_list_any_credential.dart';
import './step/the_store_is_open_and_holds_nothing.dart';
import './step/i_read_to_the_bottom_of_the_store.dart';
import './step/reading_the_store_is_slow.dart';
import './step/i_ask_about_the_store_twice.dart';
import './step/the_newer_answer_is_the_one_on_screen.dart';
import './step/the_machine_is_reached_over_ssh_as.dart';
import './step/i_open_it_here_with_its_passphrase.dart';
import './step/a_terminal_runs_on_the_machine.dart';
import './step/the_unlock_terminal_ends_and_is_put_away.dart';
import './step/the_machine_is_asked_again_whether_the_store_is_open.dart';
import './step/i_open_the_store_with_its_passphrase_from_the_lock.dart';
import './step/the_machine_is_a_socket_somebody_else_forwards.dart';
import './step/i_open_the_command_finder.dart';
import './step/the_command_is_unavailable_because.dart';
import './step/the_machine_has_no_store_yet.dart';
import './step/the_work_says.dart';
import './step/i_make_it_from_the_next_step.dart';
import './step/the_work_does_not_say.dart';
import './step/it_does_not_say.dart';
import './step/the_lock_does_not_show_an_open_store.dart';
import './step/i_make_it_here_with_a_passphrase.dart';
import './step/the_store_holds_with_the_setting_as.dart';

void main() {
  group('''Seeing and shutting the secret store, without showing a value''',
      () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await iGoToTheWork(tester);
    }

    testWidgets(
        '''what the store holds is visible without doing anything to it''',
        (tester) async {
      await bddSetUp(tester);
      await iShowTheVault(tester);
      await itListsTheCredential(tester, 'a-provider');
      await itSays(tester, 'open — its contents can be read');
      await nothingWasDoneToTheStore(tester);
    });
    testWidgets('''a value is never shown, only that something is there''',
        (tester) async {
      await bddSetUp(tester);
      await iShowTheVault(tester);
      await itSays(tester, 'api-key · 108 characters');
    });
    testWidgets('''shutting it says what locking could not reach''',
        (tester) async {
      await bddSetUp(tester);
      await twoRunningTasksStillHoldWhatTheyRead(tester);
      await iShowTheVault(tester);
      await iShutTheStore(tester);
      await itSays(tester, 'The vault is shut.');
      await itSays(
          tester, '2 running tasks still hold what they read at start');
    });
    testWidgets(
        '''a store that was already shut says so rather than claiming it did something''',
        (tester) async {
      await bddSetUp(tester);
      await theStoreWasAlreadyShut(tester);
      await iShowTheVault(tester);
      await iShutTheStore(tester);
      await itSays(tester, 'The vault was already shut.');
    });
    testWidgets('''a shut store is not an empty one''', (tester) async {
      await bddSetUp(tester);
      await theStoreIsShut(tester);
      await iShowTheVault(tester);
      await itSays(tester, 'That is not the same as it holding nothing');
      await itDoesNotListAnyCredential(tester);
    });
    testWidgets('''an open store holding nothing says that, as a state''',
        (tester) async {
      await bddSetUp(tester);
      await theStoreIsOpenAndHoldsNothing(tester);
      await iShowTheVault(tester);
      await itSays(tester,
          'It is open and holds nothing. That is a state, not a failure.');
    });
    testWidgets('''what happens at the machine instead is said in one line''',
        (tester) async {
      await bddSetUp(tester);
      await iShowTheVault(tester);
      await iReadToTheBottomOfTheStore(tester);
      await itSays(tester, '`porelo vault unlock` opens it without a device');
      await itSays(tester, '`porelo vault passphrase` changes its passphrase');
    });
    testWidgets('''a slow answer never lands on top of a newer one''',
        (tester) async {
      await bddSetUp(tester);
      await readingTheStoreIsSlow(tester);
      await iAskAboutTheStoreTwice(tester);
      await theNewerAnswerIsTheOneOnScreen(tester);
    });
    testWidgets(
        '''a shut store is opened by its passphrase in a terminal on the machine, then asked again''',
        (tester) async {
      await bddSetUp(tester);
      await theStoreIsShut(tester);
      await theMachineIsReachedOverSshAs(tester, 'alice@vm');
      await iShowTheVault(tester);
      await iOpenItHereWithItsPassphrase(tester);
      await aTerminalRunsOnTheMachine(
          tester, 'ssh -t alice@vm porelo vault unlock');
      await theUnlockTerminalEndsAndIsPutAway(tester);
      await theMachineIsAskedAgainWhetherTheStoreIsOpen(tester);
    });
    testWidgets(
        '''a shut store on a device that is not enrolled is opened from the lock by its passphrase''',
        (tester) async {
      await bddSetUp(tester);
      await theStoreIsShut(tester);
      await theMachineIsReachedOverSshAs(tester, 'alice@vm');
      await iOpenTheStoreWithItsPassphraseFromTheLock(tester);
      await aTerminalRunsOnTheMachine(
          tester, 'ssh -t alice@vm porelo vault unlock');
    });
    testWidgets(
        '''a machine whose socket somebody else forwards is not offered a terminal to open it''',
        (tester) async {
      await bddSetUp(tester);
      await theStoreIsShut(tester);
      await theMachineIsASocketSomebodyElseForwards(tester);
      await iOpenTheCommandFinder(tester);
      await theCommandIsUnavailableBecause(
          tester,
          'Open the vault with its passphrase, in a terminal',
          'forwarded by somebody else');
    });
    testWidgets(
        '''this machine's own daemon is opened by its own porelo, here''',
        (tester) async {
      await bddSetUp(tester);
      await theStoreIsShut(tester);
      await iShowTheVault(tester);
      await iOpenItHereWithItsPassphrase(tester);
      await aTerminalRunsOnTheMachine(tester, 'porelo vault unlock');
    });
    testWidgets(
        '''a machine with no store is offered to make one from the lock, in a terminal there''',
        (tester) async {
      await bddSetUp(tester);
      await theMachineIsReachedOverSshAs(tester, 'alice@vm');
      await theMachineHasNoStoreYet(tester);
      await iOpenTheStoreWithItsPassphraseFromTheLock(tester);
      await aTerminalRunsOnTheMachine(
          tester, 'ssh -t alice@vm porelo vault init');
    });
    testWidgets(
        '''a machine with no store says making it is the next step, and makes it from there''',
        (tester) async {
      await bddSetUp(tester);
      await theMachineIsReachedOverSshAs(tester, 'alice@vm');
      await theMachineHasNoStoreYet(tester);
      await theWorkSays(tester, 'Next: make the vault on');
      await iMakeItFromTheNextStep(tester);
      await aTerminalRunsOnTheMachine(
          tester, 'ssh -t alice@vm porelo vault init');
    });
    testWidgets('''a machine with a store says nothing about making one''',
        (tester) async {
      await bddSetUp(tester);
      await theWorkDoesNotSay(tester, 'Next: make the vault');
    });
    testWidgets(
        '''a machine with no store does not say one is open and empty''',
        (tester) async {
      await bddSetUp(tester);
      await theMachineHasNoStoreYet(tester);
      await iShowTheVault(tester);
      await itSays(tester, 'There is no vault yet');
      await itDoesNotSay(tester, 'It is open and holds nothing');
      await theLockDoesNotShowAnOpenStore(tester);
    });
    testWidgets(
        '''the store's own view makes one where there is none, and asks the machine afterwards''',
        (tester) async {
      await bddSetUp(tester);
      await theMachineHasNoStoreYet(tester);
      await iShowTheVault(tester);
      await iMakeItHereWithAPassphrase(tester);
      await aTerminalRunsOnTheMachine(tester, 'porelo vault init');
      await theUnlockTerminalEndsAndIsPutAway(tester);
      await theMachineIsAskedAgainWhetherTheStoreIsOpen(tester);
    });
    testWidgets('''an entry's settings are shown whole beside it''',
        (tester) async {
      await bddSetUp(tester);
      await theStoreHoldsWithTheSettingAs(
          tester, 'f56-api', 'token_url', 'https://auth.example.com/token');
      await iShowTheVault(tester);
      await itSays(tester, 'token_url: https://auth.example.com/token');
    });
  });
}
