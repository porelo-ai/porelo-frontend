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
import './step/i_choose_from_the_menu_of_the_project.dart';
import './step/it_says.dart';
import './step/i_go_on.dart';
import './step/i_agree_to_start_it.dart';
import './step/the_operation_finishes.dart';
import './step/the_agents_started_were.dart';
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
      await iChooseFromTheMenuOfTheProject(tester, 'Start an agent for each repository…', 'checkout');
      await itSays(tester, 'docs names no agent');
      await itSays(tester, 'Agent Payments runs already');
      await iGoOn(tester);
      await iGoOn(tester);
      await iAgreeToStartIt(tester);
      await theOperationFinishes(tester);
      await theAgentsStartedWere(tester, 'ledger/other-agent/ledger');
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
  });
}
