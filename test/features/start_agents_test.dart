// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_the_work.dart';
import './step/the_project_has_the_repositories.dart';
import './step/the_repository_of_names_the_agent_going_by.dart';
import './step/the_agent_works_in_of_as_and_it_runs.dart';
import './step/the_repository_of_runs_by_default_for.dart';
import './step/i_choose_from_the_menu_of_the_project.dart';
import './step/it_says.dart';
import './step/i_go_on.dart';
import './step/i_agree_to_start_it.dart';
import './step/the_operation_finishes.dart';
import './step/the_agents_started_were.dart';
import './step/no_start_named_a_model.dart';
import './step/the_task_of_in_runs_before_the_machine_says_its_agent.dart';
import './step/it_does_not_say.dart';
import './step/the_agent_works_in_of_as_and_it_is_stopped.dart';
import './step/i_leave_out.dart';
import './step/the_agent_has_nothing_to_sign_in_with.dart';
import './step/the_agent_logs_in_by_its_own_login.dart';
import './step/the_wizard_cannot_go_on_yet.dart';
import './step/nothing_was_started.dart';
import './step/i_sign_in_to_from_the_start_of_the_agents.dart';
import './step/the_login_stores_what_signed_in_with.dart';
import './step/the_unlock_terminal_ends_and_is_put_away.dart';
import './step/going_on_is_offered.dart';
import './step/the_vault_is_locked.dart';
import './step/the_vault_is_open_again.dart';
import './step/i_press.dart';
import './step/i_go_back.dart';
import './step/the_machine_fails_to_say_whether_work_can_start_with.dart';
import './step/the_machine_answers_whether_work_can_start_again.dart';
import './step/reading_the_agents_is_slow.dart';
import './step/the_machine_has_answered.dart';
import './step/the_machine_refuses_the_start_as.dart';
import './step/i_leave_the_wizard_while_it_works.dart';
import './step/the_machine_does_not_say_which_agent_its_repositories_name.dart';
import './step/i_open_the_menu_of_the_project.dart';
import './step/the_menu_offers_as_unavailable_because.dart';
import './step/the_machine_says_is.dart';
import './step/the_machine_was_asked_once_which_agents_are_signed_in.dart';
import './step/i_close_the_terminal_of_the_signin.dart';
import './step/the_machine_was_asked_to_start_signins.dart';
import './step/the_signin_ends_as.dart';
import './step/the_signins_started_were.dart';
import './step/the_signin_is_waited_on.dart';
import './step/i_close_the_wizard.dart';
import './step/the_signin_is_no_longer_waited_on.dart';
import './step/the_login_task_was_not_stopped.dart';
import './step/asking_whether_agents_are_signed_in_fails_with.dart';
import './step/the_machine_answers_which_agents_are_signed_in_again.dart';
import './step/the_machine_has_signins_of_its_own.dart';
import './step/i_watch_another_machine_called.dart';
import './step/the_machine_holds_its_list_of_projects_back.dart';
import './step/the_machine_is_chosen_behind_the_form.dart';
import './step/the_machine_gives_its_list_of_projects.dart';
import './step/the_terminal_of_the_signin_is_on_the_machine_its_form_was_opened_on.dart';
import './step/no_signin_reached_the_machine.dart';

void main() {
  group('''Starting the agent each repository names, at one click''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await iGoToTheWork(tester);
      await theProjectHasTheRepositories(tester, 'checkout', 'checkout, payments-api, ledger, docs');
      await theRepositoryOfNamesTheAgentGoingBy(tester, 'payments-api', 'checkout', 'an-agent', 'Agent Payments');
      await theRepositoryOfNamesTheAgentGoingBy(tester, 'ledger', 'checkout', 'other-agent', 'Agent ledger');
    }

    testWidgets('''one click starts the agent that is not running, and the running one is not started again''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theAgentWorksInOfAsAndItRuns(tester, 'an-agent', 'payments-api', 'checkout', 'payments-api');
      await theRepositoryOfRunsByDefaultFor(tester, 'ledger', 'checkout', 'big-model', 'a-provider');
      await iChooseFromTheMenuOfTheProject(tester, 'Start an agent for each repository…', 'checkout');
      await itSays(tester, 'docs names no agent');
      await itSays(tester, 'Agent Payments runs already');
      await iGoOn(tester);
      await iGoOn(tester);
      await iAgreeToStartIt(tester);
      await theOperationFinishes(tester);
      await theAgentsStartedWere(tester, 'ledger/other-agent/ledger');
      await noStartNamedAModel(tester);
      await itSays(tester, 'Agent ledger started');
    });
    testWidgets('''an agent just started is not offered again while the machine has not said its agent yet''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theTaskOfInRunsBeforeTheMachineSaysItsAgent(tester, 'payments-api', 'checkout', 'payments-api');
      await iChooseFromTheMenuOfTheProject(tester, 'Start an agent for each repository…', 'checkout');
      await itSays(tester, 'Agent Payments runs already');
      await itDoesNotSay(tester, 'payments-api-2');
    });
    testWidgets('''a stopped agent is brought back with its session, not started beside it''', (tester) async {
      await bddSetUp(tester);
      await theAgentWorksInOfAsAndItIsStopped(tester, 'an-agent', 'payments-api', 'checkout', 'payments-api');
      await iChooseFromTheMenuOfTheProject(tester, 'Start an agent for each repository…', 'checkout');
      await iGoOn(tester);
      await iGoOn(tester);
      await itSays(tester, 'Agent Payments continues payments-api');
      await iAgreeToStartIt(tester);
      await theOperationFinishes(tester);
      await theOperationFinishes(tester);
      await theAgentsStartedWere(tester, 'payments-api/an-agent/payments-api, ledger/other-agent/ledger');
    });
    testWidgets('''a repository left out gets no task''', (tester) async {
      await bddSetUp(tester);
      await iChooseFromTheMenuOfTheProject(tester, 'Start an agent for each repository…', 'checkout');
      await iLeaveOut(tester, 'payments-api');
      await iGoOn(tester);
      await iGoOn(tester);
      await itSays(tester, 'payments-api is left out');
      await iAgreeToStartIt(tester);
      await theOperationFinishes(tester);
      await theAgentsStartedWere(tester, 'ledger/other-agent/ledger');
    });
    testWidgets('''each agent with nothing to sign in with holds the wizard until it is signed in''', (tester) async {
      await bddSetUp(tester);
      await theAgentHasNothingToSignInWith(tester, 'an-agent');
      await theAgentHasNothingToSignInWith(tester, 'other-agent');
      await theAgentLogsInByItsOwnLogin(tester, 'an-agent');
      await theAgentLogsInByItsOwnLogin(tester, 'other-agent');
      await iChooseFromTheMenuOfTheProject(tester, 'Start an agent for each repository…', 'checkout');
      await iGoOn(tester);
      await theWizardCannotGoOnYet(tester);
      await nothingWasStarted(tester);
      await iSignInToFromTheStartOfTheAgents(tester, 'an-agent');
      await theLoginStoresWhatSignedInWith(tester, 'an-agent');
      await theUnlockTerminalEndsAndIsPutAway(tester);
      await theWizardCannotGoOnYet(tester);
      await iSignInToFromTheStartOfTheAgents(tester, 'other-agent');
      await theLoginStoresWhatSignedInWith(tester, 'other-agent');
      await theUnlockTerminalEndsAndIsPutAway(tester);
      await goingOnIsOffered(tester);
    });
    testWidgets('''a locked vault holds the wizard before the start, and it is asked again by a press''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theVaultIsLocked(tester);
      await iChooseFromTheMenuOfTheProject(tester, 'Start an agent for each repository…', 'checkout');
      await iGoOn(tester);
      await theWizardCannotGoOnYet(tester);
      await itSays(tester, 'the vault is locked, so nothing can say what it holds');
      await theVaultIsOpenAgain(tester);
      await iPress(tester, 'Ask again');
      await goingOnIsOffered(tester);
    });
    testWidgets('''a repository taken back in after the vault opened is asked again with the others''', (tester) async {
      await bddSetUp(tester);
      await theVaultIsLocked(tester);
      await iChooseFromTheMenuOfTheProject(tester, 'Start an agent for each repository…', 'checkout');
      await iLeaveOut(tester, 'payments-api');
      await iGoOn(tester);
      await theVaultIsOpenAgain(tester);
      await iPress(tester, 'Ask again');
      await iGoBack(tester);
      await iLeaveOut(tester, 'payments-api');
      await iGoOn(tester);
      await goingOnIsOffered(tester);
    });
    testWidgets('''a machine that cannot say whether work can start holds the wizard with its words''', (tester) async {
      await bddSetUp(tester);
      await theMachineFailsToSayWhetherWorkCanStartWith(tester, 'the vault could not be read');
      await iChooseFromTheMenuOfTheProject(tester, 'Start an agent for each repository…', 'checkout');
      await iGoOn(tester);
      await theWizardCannotGoOnYet(tester);
      await itSays(tester, 'the vault could not be read');
      await theMachineAnswersWhetherWorkCanStartAgain(tester);
      await iPress(tester, 'Ask again');
      await goingOnIsOffered(tester);
    });
    testWidgets('''the wizard opens while the machine is still read, and says so''', (tester) async {
      await bddSetUp(tester);
      await readingTheAgentsIsSlow(tester);
      await iChooseFromTheMenuOfTheProject(tester, 'Start an agent for each repository…', 'checkout');
      await itSays(tester, 'Wait until the machine has said which agents and tasks it has.');
      await theMachineHasAnswered(tester);
      await itDoesNotSay(tester, 'Wait until the machine has said which agents and tasks it has.');
      await itSays(tester, 'Agent ledger');
    });
    testWidgets('''going back after the starts never starts an agent a second time''', (tester) async {
      await bddSetUp(tester);
      await iChooseFromTheMenuOfTheProject(tester, 'Start an agent for each repository…', 'checkout');
      await iGoOn(tester);
      await iGoOn(tester);
      await iAgreeToStartIt(tester);
      await theMachineRefusesTheStartAs(tester, 'NOT_READY');
      await theOperationFinishes(tester);
      await iGoBack(tester);
      await iAgreeToStartIt(tester);
      await theOperationFinishes(tester);
      await theAgentsStartedWere(
        tester,
        'payments-api/an-agent/payments-api, ledger/other-agent/ledger, payments-api/an-agent/payments-api',
      );
    });
    testWidgets('''leaving while an agent starts sends no further start''', (tester) async {
      await bddSetUp(tester);
      await iChooseFromTheMenuOfTheProject(tester, 'Start an agent for each repository…', 'checkout');
      await iGoOn(tester);
      await iGoOn(tester);
      await iAgreeToStartIt(tester);
      await iLeaveTheWizardWhileItWorks(tester);
      await theOperationFinishes(tester);
      await theAgentsStartedWere(tester, 'payments-api/an-agent/payments-api');
    });
    testWidgets('''one start refused keeps its refusal while the other starts''', (tester) async {
      await bddSetUp(tester);
      await iChooseFromTheMenuOfTheProject(tester, 'Start an agent for each repository…', 'checkout');
      await iGoOn(tester);
      await iGoOn(tester);
      await iAgreeToStartIt(tester);
      await theMachineRefusesTheStartAs(tester, 'NOT_READY');
      await theOperationFinishes(tester);
      await itSays(tester, 'This project is not ready to start work.');
      await itSays(tester, 'Agent ledger started');
      await theAgentsStartedWere(tester, 'payments-api/an-agent/payments-api, ledger/other-agent/ledger');
    });
    testWidgets('''against a machine that does not say which agent a repository names, nothing is offered''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theMachineDoesNotSayWhichAgentItsRepositoriesName(tester);
      await iOpenTheMenuOfTheProject(tester, 'checkout');
      await theMenuOffersAsUnavailableBecause(
        tester,
        'Start an agent for each repository…',
        'does not say which agent',
      );
    });
    testWidgets('''two repositories of one agent make one sign-in, and nothing starts before it''', (tester) async {
      await bddSetUp(tester);
      await theRepositoryOfNamesTheAgentGoingBy(tester, 'docs', 'checkout', 'an-agent', 'Agent Docs');
      await theMachineSaysIs(tester, 'an-agent', 'NOT_SIGNED_IN');
      await iChooseFromTheMenuOfTheProject(tester, 'Start an agent for each repository…', 'checkout');
      await iGoOn(tester);
      await theMachineWasAskedOnceWhichAgentsAreSignedIn(tester);
      await theWizardCannotGoOnYet(tester);
      await iPress(tester, 'Sign in');
      await iCloseTheTerminalOfTheSignin(tester);
      await theMachineWasAskedToStartSignins(tester, 1);
      await theSigninEndsAs(tester, 'SIGNED_IN');
      await goingOnIsOffered(tester);
      await nothingWasStarted(tester);
    });
    testWidgets('''the next agent is signed in only once the one before is, and nothing starts before all are''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theMachineSaysIs(tester, 'an-agent', 'NOT_SIGNED_IN');
      await theMachineSaysIs(tester, 'other-agent', 'NOT_SIGNED_IN');
      await iChooseFromTheMenuOfTheProject(tester, 'Start an agent for each repository…', 'checkout');
      await iGoOn(tester);
      await iPress(tester, 'Sign in');
      await iCloseTheTerminalOfTheSignin(tester);
      await iPress(tester, 'Sign in');
      await iCloseTheTerminalOfTheSignin(tester);
      await theSigninsStartedWere(tester, 'an-agent');
      await theSigninEndsAs(tester, 'SIGNED_IN');
      await theWizardCannotGoOnYet(tester);
      await nothingWasStarted(tester);
      await iPress(tester, 'Sign in');
      await iCloseTheTerminalOfTheSignin(tester);
      await theSigninsStartedWere(tester, 'an-agent, other-agent');
      await theSigninEndsAs(tester, 'SIGNED_IN');
      await goingOnIsOffered(tester);
    });
    testWidgets('''Outline: a sign-in that fails or is ended holds every start ('NOT_SIGNED_IN')''', (tester) async {
      await bddSetUp(tester);
      await theMachineSaysIs(tester, 'an-agent', 'NOT_SIGNED_IN');
      await iChooseFromTheMenuOfTheProject(tester, 'Start an agent for each repository…', 'checkout');
      await iGoOn(tester);
      await iPress(tester, 'Sign in');
      await iCloseTheTerminalOfTheSignin(tester);
      await theSigninEndsAs(tester, 'NOT_SIGNED_IN');
      await theWizardCannotGoOnYet(tester);
      await nothingWasStarted(tester);
    });
    testWidgets('''Outline: a sign-in that fails or is ended holds every start ('cut')''', (tester) async {
      await bddSetUp(tester);
      await theMachineSaysIs(tester, 'an-agent', 'NOT_SIGNED_IN');
      await iChooseFromTheMenuOfTheProject(tester, 'Start an agent for each repository…', 'checkout');
      await iGoOn(tester);
      await iPress(tester, 'Sign in');
      await iCloseTheTerminalOfTheSignin(tester);
      await theSigninEndsAs(tester, 'cut');
      await theWizardCannotGoOnYet(tester);
      await nothingWasStarted(tester);
    });
    testWidgets('''closing the wizard during a sign-in starts nothing and leaves the login task''', (tester) async {
      await bddSetUp(tester);
      await theMachineSaysIs(tester, 'an-agent', 'NOT_SIGNED_IN');
      await iChooseFromTheMenuOfTheProject(tester, 'Start an agent for each repository…', 'checkout');
      await iGoOn(tester);
      await iPress(tester, 'Sign in');
      await iCloseTheTerminalOfTheSignin(tester);
      await theSigninIsWaitedOn(tester);
      await iCloseTheWizard(tester);
      await theSigninIsNoLongerWaitedOn(tester);
      await iGoToTheWork(tester);
      await itSays(tester, 'The sign-in to An Agent goes on in its own task');
      await theSigninEndsAs(tester, 'SIGNED_IN');
      await nothingWasStarted(tester);
      await theLoginTaskWasNotStopped(tester);
    });
    testWidgets(
      '''an agent listed signed in while the machine says its credential is missing is offered its sign-in''',
      (tester) async {
        await bddSetUp(tester);
        await theMachineSaysIs(tester, 'an-agent', 'SIGNED_IN');
        await theAgentHasNothingToSignInWith(tester, 'an-agent');
        await iChooseFromTheMenuOfTheProject(tester, 'Start an agent for each repository…', 'checkout');
        await iGoOn(tester);
        await theWizardCannotGoOnYet(tester);
        await iPress(tester, 'Sign in');
        await iCloseTheTerminalOfTheSignin(tester);
        await theSigninsStartedWere(tester, 'an-agent');
        await nothingWasStarted(tester);
      },
    );
    testWidgets('''a machine that could not say which agents are signed in is asked again by a press''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theMachineSaysIs(tester, 'an-agent', 'SIGNED_IN');
      await askingWhetherAgentsAreSignedInFailsWith(tester, 'a refusal');
      await iChooseFromTheMenuOfTheProject(tester, 'Start an agent for each repository…', 'checkout');
      await iGoOn(tester);
      await theWizardCannotGoOnYet(tester);
      await theMachineAnswersWhichAgentsAreSignedInAgain(tester);
      await iPress(tester, 'Ask again');
      await goingOnIsOffered(tester);
    });
    testWidgets('''leaving out the repository whose agent signs in moves on to the next agent''', (tester) async {
      await bddSetUp(tester);
      await theMachineSaysIs(tester, 'an-agent', 'SIGNING_IN');
      await theMachineSaysIs(tester, 'other-agent', 'NOT_SIGNED_IN');
      await iChooseFromTheMenuOfTheProject(tester, 'Start an agent for each repository…', 'checkout');
      await iLeaveOut(tester, 'payments-api');
      await iGoOn(tester);
      await iPress(tester, 'Sign in');
      await iCloseTheTerminalOfTheSignin(tester);
      await theSigninsStartedWere(tester, 'other-agent');
      await theLoginTaskWasNotStopped(tester);
      await nothingWasStarted(tester);
    });
    testWidgets('''the wizard opens on the machine it was chosen on, not on one chosen while the machine was read''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theMachineSaysIs(tester, 'an-agent', 'NOT_SIGNED_IN');
      await theMachineHasSigninsOfItsOwn(tester, 'elsewhere');
      await iWatchAnotherMachineCalled(tester, 'elsewhere');
      await iGoToTheWork(tester);
      await theMachineHoldsItsListOfProjectsBack(tester);
      await iChooseFromTheMenuOfTheProject(tester, 'Start an agent for each repository…', 'checkout');
      await theMachineIsChosenBehindTheForm(tester, 'elsewhere');
      await theMachineGivesItsListOfProjects(tester);
      await theMachineWasAskedOnceWhichAgentsAreSignedIn(tester);
      await iGoOn(tester);
      await iPress(tester, 'Sign in');
      await theTerminalOfTheSigninIsOnTheMachineItsFormWasOpenedOn(tester);
      await noSigninReachedTheMachine(tester, 'elsewhere');
    });
  });
}
