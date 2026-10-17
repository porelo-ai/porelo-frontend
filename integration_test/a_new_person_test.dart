// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import './step/the_account_of_a_person_new_to_porelo_as_it_was_given_to_them.dart';
import './step/the_interface_is_running.dart';
import './step/i_add_the_machine_i_was_given_knowing_only_how_i_log_into_it.dart';
import './step/the_machine_is_answering.dart';
import './step/i_make_the_vault_choosing_its_passphrase_in_the_terminal_the_interface_opens.dart';
import './step/the_vault_is_open.dart';
import './step/i_have_a_repository_on_that_machine.dart';
import './step/i_start_work_on_it_in_default_as_the_window_offers.dart';
import './step/the_work_starts_on_which_is_in_default_now.dart';
import './step/i_choose_as_the_agent.dart';
import './step/i_am_offered_to_log_in_with.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('''A person new to Porelo, from an empty account, in the interface''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await theAccountOfAPersonNewToPoreloAsItWasGivenToThem(tester);
      await theInterfaceIsRunning(tester);
    }

    testWidgets('''a new person goes from an empty account to work on a repository of theirs''', (tester) async {
      await bddSetUp(tester);
      await iAddTheMachineIWasGivenKnowingOnlyHowILogIntoIt(tester);
      await theMachineIsAnswering(tester);
      await iMakeTheVaultChoosingItsPassphraseInTheTerminalTheInterfaceOpens(tester);
      await theVaultIsOpen(tester);
      await iHaveARepositoryOnThatMachine(tester, 'my-first');
      await iStartWorkOnItInDefaultAsTheWindowOffers(tester);
      await theWorkStartsOnWhichIsInDefaultNow(tester, 'my-first');
      await iChooseAsTheAgent(tester, 'Claude');
      await iAmOfferedToLogInWith(tester, 'Claude');
    });
  });
}
