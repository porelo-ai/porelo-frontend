// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_the_work.dart';
import './step/i_select_the_project.dart';
import './step/the_machine_says_is.dart';
import './step/i_start_work_in_this_project.dart';
import './step/i_call_it.dart';
import './step/i_choose_the_agent.dart';
import './step/i_start_it.dart';
import './step/starting_is_not_offered_yet.dart';
import './step/nothing_was_started.dart';
import './step/asking_whether_agents_are_signed_in_fails_with.dart';
import './step/i_press.dart';
import './step/i_close_the_terminal_of_the_signin.dart';
import './step/the_signin_ends_as.dart';
import './step/starting_is_offered.dart';
import './step/the_vault_holds_no_credential_for_what_a_run_would_use.dart';
import './step/a_signin_of_already_runs_on_the_machine.dart';
import './step/the_signin_is_waited_on.dart';
import './step/the_terminal_of_is_open_over_the_form.dart';
import './step/the_machine_was_asked_to_start_signins.dart';
import './step/no_signin_was_forced.dart';
import './step/the_machine_answers_a_signin_start_with_running_already.dart';
import './step/i_leave_the_start_form_by.dart';
import './step/the_signin_is_no_longer_waited_on.dart';
import './step/the_signin_still_runs_on_the_machine.dart';
import './step/it_says.dart';
import './step/i_watch_another_machine_called.dart';
import './step/the_machine_of_the_form_is_forgotten.dart';
import './step/the_machine_is_reached_over_ssh_as.dart';
import './step/the_machine_was_told_the_person_reaches_it_from_another_one.dart';
import './step/the_terminal_of_the_signin_runs_over_ssh_on.dart';
import './step/the_machine_refuses_the_signin_as.dart';
import './step/the_last_signin_was_forced.dart';
import './step/the_machine_has_signins_of_its_own.dart';
import './step/the_machine_is_chosen_behind_the_form.dart';
import './step/the_terminal_of_the_signin_is_on_the_machine_its_form_was_opened_on.dart';
import './step/the_start_reached_only_the_machine_its_form_was_opened_on.dart';
import './step/no_signin_reached_the_machine.dart';
import './step/the_machine_refuses_the_start_as.dart';
import './step/one_start_was_sent.dart';
import './step/i_choose_the_command.dart';
import './step/i_close_what_is_open.dart';
import './step/the_machine_holds_the_signin_start_back.dart';
import './step/the_machine_answers_the_signin_start.dart';
import './step/no_signin_is_waited_on.dart';
import './step/no_terminal_of_a_signin_was_opened.dart';

void main() {
  group('''Signing the agent in before work starts on its machine''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await iGoToTheWork(tester);
      await iSelectTheProject(tester, 'checkout');
    }

    testWidgets('''Outline: an agent the machine does not read as signed in starts nothing ('NOT_SIGNED_IN')''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theMachineSaysIs(tester, 'an-agent', 'NOT_SIGNED_IN');
      await iStartWorkInThisProject(tester);
      await iCallIt(tester, 'schema-work');
      await iChooseTheAgent(tester, 'An Agent');
      await iStartIt(tester);
      await startingIsNotOfferedYet(tester);
      await nothingWasStarted(tester);
    });
    testWidgets('''Outline: an agent the machine does not read as signed in starts nothing ('VAULT_LOCKED')''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theMachineSaysIs(tester, 'an-agent', 'VAULT_LOCKED');
      await iStartWorkInThisProject(tester);
      await iCallIt(tester, 'schema-work');
      await iChooseTheAgent(tester, 'An Agent');
      await iStartIt(tester);
      await startingIsNotOfferedYet(tester);
      await nothingWasStarted(tester);
    });
    testWidgets('''Outline: an agent the machine does not read as signed in starts nothing ('HALF_SIGNED_IN')''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theMachineSaysIs(tester, 'an-agent', 'HALF_SIGNED_IN');
      await iStartWorkInThisProject(tester);
      await iCallIt(tester, 'schema-work');
      await iChooseTheAgent(tester, 'An Agent');
      await iStartIt(tester);
      await startingIsNotOfferedYet(tester);
      await nothingWasStarted(tester);
    });
    testWidgets('''Outline: a machine that cannot say whether the agent is signed in starts nothing ('a refusal')''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theMachineSaysIs(tester, 'an-agent', 'SIGNED_IN');
      await askingWhetherAgentsAreSignedInFailsWith(tester, 'a refusal');
      await iStartWorkInThisProject(tester);
      await iCallIt(tester, 'schema-work');
      await iChooseTheAgent(tester, 'An Agent');
      await iStartIt(tester);
      await startingIsNotOfferedYet(tester);
      await nothingWasStarted(tester);
    });
    testWidgets(
      '''Outline: a machine that cannot say whether the agent is signed in starts nothing ('a lost connection')''',
      (tester) async {
        await bddSetUp(tester);
        await theMachineSaysIs(tester, 'an-agent', 'SIGNED_IN');
        await askingWhetherAgentsAreSignedInFailsWith(tester, 'a lost connection');
        await iStartWorkInThisProject(tester);
        await iCallIt(tester, 'schema-work');
        await iChooseTheAgent(tester, 'An Agent');
        await iStartIt(tester);
        await startingIsNotOfferedYet(tester);
        await nothingWasStarted(tester);
      },
    );
    testWidgets('''Outline: a sign-in that ends before the agent is signed in starts nothing ('NOT_SIGNED_IN')''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theMachineSaysIs(tester, 'an-agent', 'NOT_SIGNED_IN');
      await iStartWorkInThisProject(tester);
      await iCallIt(tester, 'schema-work');
      await iChooseTheAgent(tester, 'An Agent');
      await iPress(tester, 'Sign in');
      await iCloseTheTerminalOfTheSignin(tester);
      await theSigninEndsAs(tester, 'NOT_SIGNED_IN');
      await iStartIt(tester);
      await startingIsNotOfferedYet(tester);
      await nothingWasStarted(tester);
    });
    testWidgets(
      '''Outline: a sign-in that ends before the agent is signed in starts nothing ('NOTHING_TO_COLLECT')''',
      (tester) async {
        await bddSetUp(tester);
        await theMachineSaysIs(tester, 'an-agent', 'NOT_SIGNED_IN');
        await iStartWorkInThisProject(tester);
        await iCallIt(tester, 'schema-work');
        await iChooseTheAgent(tester, 'An Agent');
        await iPress(tester, 'Sign in');
        await iCloseTheTerminalOfTheSignin(tester);
        await theSigninEndsAs(tester, 'NOTHING_TO_COLLECT');
        await iStartIt(tester);
        await startingIsNotOfferedYet(tester);
        await nothingWasStarted(tester);
      },
    );
    testWidgets('''Outline: a sign-in that ends before the agent is signed in starts nothing ('VAULT_LOCKED')''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theMachineSaysIs(tester, 'an-agent', 'NOT_SIGNED_IN');
      await iStartWorkInThisProject(tester);
      await iCallIt(tester, 'schema-work');
      await iChooseTheAgent(tester, 'An Agent');
      await iPress(tester, 'Sign in');
      await iCloseTheTerminalOfTheSignin(tester);
      await theSigninEndsAs(tester, 'VAULT_LOCKED');
      await iStartIt(tester);
      await startingIsNotOfferedYet(tester);
      await nothingWasStarted(tester);
    });
    testWidgets('''Outline: a sign-in that ends before the agent is signed in starts nothing ('TIMED_OUT')''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theMachineSaysIs(tester, 'an-agent', 'NOT_SIGNED_IN');
      await iStartWorkInThisProject(tester);
      await iCallIt(tester, 'schema-work');
      await iChooseTheAgent(tester, 'An Agent');
      await iPress(tester, 'Sign in');
      await iCloseTheTerminalOfTheSignin(tester);
      await theSigninEndsAs(tester, 'TIMED_OUT');
      await iStartIt(tester);
      await startingIsNotOfferedYet(tester);
      await nothingWasStarted(tester);
    });
    testWidgets('''Outline: a sign-in that ends before the agent is signed in starts nothing ('SIGNING_UP')''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theMachineSaysIs(tester, 'an-agent', 'NOT_SIGNED_IN');
      await iStartWorkInThisProject(tester);
      await iCallIt(tester, 'schema-work');
      await iChooseTheAgent(tester, 'An Agent');
      await iPress(tester, 'Sign in');
      await iCloseTheTerminalOfTheSignin(tester);
      await theSigninEndsAs(tester, 'SIGNING_UP');
      await iStartIt(tester);
      await startingIsNotOfferedYet(tester);
      await nothingWasStarted(tester);
    });
    testWidgets('''Outline: a sign-in that ends before the agent is signed in starts nothing ('cut')''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theMachineSaysIs(tester, 'an-agent', 'NOT_SIGNED_IN');
      await iStartWorkInThisProject(tester);
      await iCallIt(tester, 'schema-work');
      await iChooseTheAgent(tester, 'An Agent');
      await iPress(tester, 'Sign in');
      await iCloseTheTerminalOfTheSignin(tester);
      await theSigninEndsAs(tester, 'cut');
      await iStartIt(tester);
      await startingIsNotOfferedYet(tester);
      await nothingWasStarted(tester);
    });
    testWidgets('''once signed in nothing starts by itself, and starting is offered''', (tester) async {
      await bddSetUp(tester);
      await theMachineSaysIs(tester, 'an-agent', 'NOT_SIGNED_IN');
      await iStartWorkInThisProject(tester);
      await iCallIt(tester, 'schema-work');
      await iChooseTheAgent(tester, 'An Agent');
      await iPress(tester, 'Sign in');
      await iCloseTheTerminalOfTheSignin(tester);
      await theSigninEndsAs(tester, 'SIGNED_IN');
      await nothingWasStarted(tester);
      await startingIsOffered(tester);
    });
    testWidgets('''signed in while the machine still says the credential is missing starts nothing''', (tester) async {
      await bddSetUp(tester);
      await theMachineSaysIs(tester, 'an-agent', 'NOT_SIGNED_IN');
      await theVaultHoldsNoCredentialForWhatARunWouldUse(tester);
      await iStartWorkInThisProject(tester);
      await iCallIt(tester, 'schema-work');
      await iChooseTheAgent(tester, 'An Agent');
      await iPress(tester, 'Sign in');
      await iCloseTheTerminalOfTheSignin(tester);
      await theSigninEndsAs(tester, 'SIGNED_IN');
      await iStartIt(tester);
      await startingIsNotOfferedYet(tester);
      await nothingWasStarted(tester);
    });
    testWidgets('''an agent the machine cannot say of starts where the machine says work can start''', (tester) async {
      await bddSetUp(tester);
      await theMachineSaysIs(tester, 'an-agent', 'CANNOT_SAY');
      await iStartWorkInThisProject(tester);
      await iCallIt(tester, 'schema-work');
      await iChooseTheAgent(tester, 'An Agent');
      await startingIsOffered(tester);
      await nothingWasStarted(tester);
    });
    testWidgets(
      '''an agent the machine cannot say of starts nothing while the machine says the credential is missing''',
      (tester) async {
        await bddSetUp(tester);
        await theMachineSaysIs(tester, 'an-agent', 'CANNOT_SAY');
        await theVaultHoldsNoCredentialForWhatARunWouldUse(tester);
        await iStartWorkInThisProject(tester);
        await iCallIt(tester, 'schema-work');
        await iChooseTheAgent(tester, 'An Agent');
        await iStartIt(tester);
        await startingIsNotOfferedYet(tester);
        await nothingWasStarted(tester);
      },
    );
    testWidgets(
      '''Outline: a sign-in that ends as the machine cannot say starts where the machine says work can start ('CANNOT_SAY')''',
      (tester) async {
        await bddSetUp(tester);
        await theMachineSaysIs(tester, 'an-agent', 'NOT_SIGNED_IN');
        await iStartWorkInThisProject(tester);
        await iCallIt(tester, 'schema-work');
        await iChooseTheAgent(tester, 'An Agent');
        await iPress(tester, 'Sign in');
        await iCloseTheTerminalOfTheSignin(tester);
        await theSigninEndsAs(tester, 'CANNOT_SAY');
        await startingIsOffered(tester);
        await nothingWasStarted(tester);
      },
    );
    testWidgets(
      '''Outline: a sign-in that ends as the machine cannot say starts where the machine says work can start ('NO_PROVIDER')''',
      (tester) async {
        await bddSetUp(tester);
        await theMachineSaysIs(tester, 'an-agent', 'NOT_SIGNED_IN');
        await iStartWorkInThisProject(tester);
        await iCallIt(tester, 'schema-work');
        await iChooseTheAgent(tester, 'An Agent');
        await iPress(tester, 'Sign in');
        await iCloseTheTerminalOfTheSignin(tester);
        await theSigninEndsAs(tester, 'NO_PROVIDER');
        await startingIsOffered(tester);
        await nothingWasStarted(tester);
      },
    );
    testWidgets('''a sign-in that runs already is waited on, and its own terminal opened, never a second''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await aSigninOfAlreadyRunsOnTheMachine(tester, 'an-agent');
      await iStartWorkInThisProject(tester);
      await iChooseTheAgent(tester, 'An Agent');
      await theSigninIsWaitedOn(tester);
      await iPress(tester, 'Sign in');
      await theTerminalOfIsOpenOverTheForm(tester, 'porelo-login-an-agent');
      await theMachineWasAskedToStartSignins(tester, 1);
      await noSigninWasForced(tester);
    });
    testWidgets('''a sign-in the machine finds running is opened and waited on, and not started again''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theMachineSaysIs(tester, 'an-agent', 'NOT_SIGNED_IN');
      await theMachineAnswersASigninStartWithRunningAlready(tester, 'porelo-login-an-agent');
      await iStartWorkInThisProject(tester);
      await iChooseTheAgent(tester, 'An Agent');
      await iPress(tester, 'Sign in');
      await theTerminalOfIsOpenOverTheForm(tester, 'porelo-login-an-agent');
      await theSigninIsWaitedOn(tester);
      await iCloseTheTerminalOfTheSignin(tester);
      await iPress(tester, 'Sign in');
      await theTerminalOfIsOpenOverTheForm(tester, 'porelo-login-an-agent');
      await theMachineWasAskedToStartSignins(tester, 1);
    });
    testWidgets(
      '''Outline: leaving the form during a sign-in starts nothing and leaves the sign-in running ('Escape')''',
      (tester) async {
        await bddSetUp(tester);
        await theMachineSaysIs(tester, 'an-agent', 'NOT_SIGNED_IN');
        await iStartWorkInThisProject(tester);
        await iCallIt(tester, 'schema-work');
        await iChooseTheAgent(tester, 'An Agent');
        await iPress(tester, 'Sign in');
        await iCloseTheTerminalOfTheSignin(tester);
        await iLeaveTheStartFormBy(tester, 'Escape');
        await theSigninIsNoLongerWaitedOn(tester);
        await theSigninEndsAs(tester, 'SIGNED_IN');
        await nothingWasStarted(tester);
        await theSigninStillRunsOnTheMachine(tester);
        await itSays(tester, 'The sign-in to An Agent goes on by itself');
        await itSays(tester, 'until it is finished or 30 minutes pass');
      },
    );
    testWidgets(
      '''Outline: leaving the form during a sign-in starts nothing and leaves the sign-in running ('the barrier')''',
      (tester) async {
        await bddSetUp(tester);
        await theMachineSaysIs(tester, 'an-agent', 'NOT_SIGNED_IN');
        await iStartWorkInThisProject(tester);
        await iCallIt(tester, 'schema-work');
        await iChooseTheAgent(tester, 'An Agent');
        await iPress(tester, 'Sign in');
        await iCloseTheTerminalOfTheSignin(tester);
        await iLeaveTheStartFormBy(tester, 'the barrier');
        await theSigninIsNoLongerWaitedOn(tester);
        await theSigninEndsAs(tester, 'SIGNED_IN');
        await nothingWasStarted(tester);
        await theSigninStillRunsOnTheMachine(tester);
        await itSays(tester, 'The sign-in to An Agent goes on by itself');
        await itSays(tester, 'until it is finished or 30 minutes pass');
      },
    );
    testWidgets(
      '''Outline: leaving the form during a sign-in starts nothing and leaves the sign-in running ('Not now')''',
      (tester) async {
        await bddSetUp(tester);
        await theMachineSaysIs(tester, 'an-agent', 'NOT_SIGNED_IN');
        await iStartWorkInThisProject(tester);
        await iCallIt(tester, 'schema-work');
        await iChooseTheAgent(tester, 'An Agent');
        await iPress(tester, 'Sign in');
        await iCloseTheTerminalOfTheSignin(tester);
        await iLeaveTheStartFormBy(tester, 'Not now');
        await theSigninIsNoLongerWaitedOn(tester);
        await theSigninEndsAs(tester, 'SIGNED_IN');
        await nothingWasStarted(tester);
        await theSigninStillRunsOnTheMachine(tester);
        await itSays(tester, 'The sign-in to An Agent goes on by itself');
        await itSays(tester, 'until it is finished or 30 minutes pass');
      },
    );
    testWidgets('''forgetting the machine of the form drops the wait on its sign-in''', (tester) async {
      await bddSetUp(tester);
      await theMachineSaysIs(tester, 'an-agent', 'NOT_SIGNED_IN');
      await iWatchAnotherMachineCalled(tester, 'elsewhere');
      await iGoToTheWork(tester);
      await iSelectTheProject(tester, 'checkout');
      await iStartWorkInThisProject(tester);
      await iCallIt(tester, 'schema-work');
      await iChooseTheAgent(tester, 'An Agent');
      await iPress(tester, 'Sign in');
      await iCloseTheTerminalOfTheSignin(tester);
      await theSigninIsWaitedOn(tester);
      await theMachineOfTheFormIsForgotten(tester);
      await theSigninIsNoLongerWaitedOn(tester);
      await theSigninStillRunsOnTheMachine(tester);
    });
    testWidgets('''a sign-in on a machine reached over ssh says so and attaches over ssh there''', (tester) async {
      await bddSetUp(tester);
      await theMachineSaysIs(tester, 'an-agent', 'NOT_SIGNED_IN');
      await theMachineIsReachedOverSshAs(tester, 'alice@vm');
      await iGoToTheWork(tester);
      await iSelectTheProject(tester, 'checkout');
      await iStartWorkInThisProject(tester);
      await iCallIt(tester, 'schema-work');
      await iChooseTheAgent(tester, 'An Agent');
      await iPress(tester, 'Sign in');
      await theMachineWasToldThePersonReachesItFromAnotherOne(tester);
      await theTerminalOfTheSigninRunsOverSshOn(tester, 'alice@vm');
    });
    testWidgets('''a machine that holds a sign-in already offers its import, and forces nothing by itself''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theMachineSaysIs(tester, 'an-agent', 'NOT_SIGNED_IN');
      await theMachineRefusesTheSigninAs(tester, 'ALREADY_SIGNED_IN');
      await iStartWorkInThisProject(tester);
      await iCallIt(tester, 'schema-work');
      await iChooseTheAgent(tester, 'An Agent');
      await iPress(tester, 'Sign in');
      await theMachineWasAskedToStartSignins(tester, 1);
      await noSigninWasForced(tester);
      await startingIsNotOfferedYet(tester);
      await iPress(tester, 'Use the sign-in found on the machine');
      await startingIsOffered(tester);
      await noSigninWasForced(tester);
      await nothingWasStarted(tester);
    });
    testWidgets('''a sign-in anyway is the second press after the machine said it holds one''', (tester) async {
      await bddSetUp(tester);
      await theMachineSaysIs(tester, 'an-agent', 'NOT_SIGNED_IN');
      await theMachineRefusesTheSigninAs(tester, 'ALREADY_SIGNED_IN');
      await iStartWorkInThisProject(tester);
      await iCallIt(tester, 'schema-work');
      await iChooseTheAgent(tester, 'An Agent');
      await iPress(tester, 'Sign in');
      await iPress(tester, 'Sign in anyway, beside the sign-in found');
      await theLastSigninWasForced(tester);
      await theTerminalOfIsOpenOverTheForm(tester, 'porelo-login-an-agent');
      await startingIsNotOfferedYet(tester);
    });
    testWidgets('''a sign-in goes to the machine its form was opened on, not to one chosen meanwhile''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theMachineSaysIs(tester, 'an-agent', 'NOT_SIGNED_IN');
      await theMachineHasSigninsOfItsOwn(tester, 'elsewhere');
      await iWatchAnotherMachineCalled(tester, 'elsewhere');
      await iGoToTheWork(tester);
      await iSelectTheProject(tester, 'checkout');
      await iStartWorkInThisProject(tester);
      await theMachineIsChosenBehindTheForm(tester, 'elsewhere');
      await iCallIt(tester, 'schema-work');
      await iChooseTheAgent(tester, 'An Agent');
      await iPress(tester, 'Sign in');
      await theTerminalOfTheSigninIsOnTheMachineItsFormWasOpenedOn(tester);
      await iCloseTheTerminalOfTheSignin(tester);
      await theSigninEndsAs(tester, 'SIGNED_IN');
      await iStartIt(tester);
      await theStartReachedOnlyTheMachineItsFormWasOpenedOn(tester);
      await noSigninReachedTheMachine(tester, 'elsewhere');
    });
    testWidgets(
      '''a start that fails while the agent reads not signed in offers the sign-in, and is not sent again''',
      (tester) async {
        await bddSetUp(tester);
        await theMachineSaysIs(tester, 'an-agent', 'SIGNED_IN');
        await iStartWorkInThisProject(tester);
        await iCallIt(tester, 'schema-work');
        await iChooseTheAgent(tester, 'An Agent');
        await iStartIt(tester);
        await theMachineSaysIs(tester, 'an-agent', 'NOT_SIGNED_IN');
        await theMachineRefusesTheStartAs(tester, 'NOT_READY');
        await iPress(tester, 'Sign in');
        await theMachineWasAskedToStartSignins(tester, 1);
        await oneStartWasSent(tester);
      },
    );
    testWidgets('''the sign-in a failed start offers is reached from the command finder too''', (tester) async {
      await bddSetUp(tester);
      await theMachineSaysIs(tester, 'an-agent', 'SIGNED_IN');
      await iStartWorkInThisProject(tester);
      await iCallIt(tester, 'schema-work');
      await iChooseTheAgent(tester, 'An Agent');
      await iStartIt(tester);
      await theMachineSaysIs(tester, 'an-agent', 'NOT_SIGNED_IN');
      await theMachineRefusesTheStartAs(tester, 'NOT_READY');
      await iChooseTheCommand(tester, 'Sign in');
      await theMachineWasAskedToStartSignins(tester, 1);
      await oneStartWasSent(tester);
    });
    testWidgets('''leaving the failed start's view drops the wait on its sign-in and leaves the sign-in running''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theMachineSaysIs(tester, 'an-agent', 'SIGNED_IN');
      await iStartWorkInThisProject(tester);
      await iCallIt(tester, 'schema-work');
      await iChooseTheAgent(tester, 'An Agent');
      await iStartIt(tester);
      await theMachineSaysIs(tester, 'an-agent', 'NOT_SIGNED_IN');
      await theMachineRefusesTheStartAs(tester, 'NOT_READY');
      await iPress(tester, 'Sign in');
      await iCloseTheTerminalOfTheSignin(tester);
      await theSigninIsWaitedOn(tester);
      await iCloseWhatIsOpen(tester);
      await theSigninIsNoLongerWaitedOn(tester);
      await theSigninStillRunsOnTheMachine(tester);
    });
    testWidgets('''leaving the failed start's view while its sign-in starts opens no wait and no terminal''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theMachineSaysIs(tester, 'an-agent', 'SIGNED_IN');
      await iStartWorkInThisProject(tester);
      await iCallIt(tester, 'schema-work');
      await iChooseTheAgent(tester, 'An Agent');
      await iStartIt(tester);
      await theMachineSaysIs(tester, 'an-agent', 'NOT_SIGNED_IN');
      await theMachineRefusesTheStartAs(tester, 'NOT_READY');
      await theMachineHoldsTheSigninStartBack(tester);
      await iPress(tester, 'Sign in');
      await iCloseWhatIsOpen(tester);
      await theMachineAnswersTheSigninStart(tester);
      await noSigninIsWaitedOn(tester);
      await noTerminalOfASigninWasOpened(tester);
    });
    testWidgets('''forgetting the machine while its sign-in starts opens no wait and no terminal''', (tester) async {
      await bddSetUp(tester);
      await theMachineSaysIs(tester, 'an-agent', 'NOT_SIGNED_IN');
      await iWatchAnotherMachineCalled(tester, 'elsewhere');
      await iGoToTheWork(tester);
      await iSelectTheProject(tester, 'checkout');
      await iStartWorkInThisProject(tester);
      await iCallIt(tester, 'schema-work');
      await iChooseTheAgent(tester, 'An Agent');
      await theMachineHoldsTheSigninStartBack(tester);
      await iPress(tester, 'Sign in');
      await theMachineOfTheFormIsForgotten(tester);
      await theMachineAnswersTheSigninStart(tester);
      await noSigninIsWaitedOn(tester);
      await noTerminalOfASigninWasOpened(tester);
    });
  });
}
