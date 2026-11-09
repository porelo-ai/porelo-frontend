// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_the_work.dart';
import './step/i_select_the_project.dart';
import './step/the_project_has_the_repositories.dart';
import './step/the_machine_says_it_does_not_carry_the_repository.dart';
import './step/i_open_from_the_projects_of_this_machine.dart';
import './step/the_repository_says.dart';
import './step/the_repository_does_not_say.dart';
import './step/the_repository_cannot_be_started_from_its_row.dart';
import './step/i_start_work_in_this_project.dart';
import './step/the_repository_is_not_offered_to_start_in.dart';
import './step/the_repository_is_offered_to_start_in.dart';
import './step/the_machine_says_the_repository_stands_against_central_with_no_count.dart';
import './step/the_machine_says_it_carries_the_repository.dart';
import './step/the_machine_counts_running_of_tasks_in_the_repository.dart';

void main() {
  group('''What a machine says of each repository of a project it holds''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await iGoToTheWork(tester);
      await iSelectTheProject(tester, 'checkout');
      await theProjectHasTheRepositories(tester, 'checkout', 'checkout, payments-api, billing');
    }

    testWidgets('''a repository the machine does not carry says so, and its row starts nothing''', (tester) async {
      await bddSetUp(tester);
      await theMachineSaysItDoesNotCarryTheRepository(tester, 'billing');
      await iOpenFromTheProjectsOfThisMachine(tester, 'checkout');
      await theRepositorySays(tester, 'billing', 'not carried here');
      await theRepositoryDoesNotSay(tester, 'billing', 'on the machine');
      await theRepositoryCannotBeStartedFromItsRow(tester, 'billing');
    });
    testWidgets('''a repository the machine does not carry is not offered to start in''', (tester) async {
      await bddSetUp(tester);
      await theMachineSaysItDoesNotCarryTheRepository(tester, 'billing');
      await iStartWorkInThisProject(tester);
      await theRepositoryIsNotOfferedToStartIn(tester, 'billing');
      await theRepositoryIsOfferedToStartIn(tester, 'payments-api');
    });
    testWidgets('''ahead of central with no count reported is never none ahead''', (tester) async {
      await bddSetUp(tester);
      await theMachineSaysTheRepositoryStandsAgainstCentralWithNoCount(tester, 'payments-api', 'ahead');
      await iOpenFromTheProjectsOfThisMachine(tester, 'checkout');
      await theRepositorySays(tester, 'payments-api', 'ahead of central, by how much not reported');
      await theRepositoryDoesNotSay(tester, 'payments-api', '0 commits');
    });
    testWidgets('''a central state not reported yet is never at central''', (tester) async {
      await bddSetUp(tester);
      await theMachineSaysItCarriesTheRepository(tester, 'payments-api');
      await iOpenFromTheProjectsOfThisMachine(tester, 'checkout');
      await theRepositorySays(tester, 'payments-api', 'central: not reported');
      await theRepositoryDoesNotSay(tester, 'payments-api', 'at central');
    });
    testWidgets('''a central state of a later Porelo is shown as it comes, never as at central''', (tester) async {
      await bddSetUp(tester);
      await theMachineSaysTheRepositoryStandsAgainstCentralWithNoCount(tester, 'payments-api', 'diverged');
      await iOpenFromTheProjectsOfThisMachine(tester, 'checkout');
      await theRepositorySays(tester, 'payments-api', 'central: diverged');
      await theRepositoryDoesNotSay(tester, 'payments-api', 'at central');
    });
    testWidgets('''work the machine counts as running is never said to be none''', (tester) async {
      await bddSetUp(tester);
      await theMachineCountsRunningOfTasksInTheRepository(tester, '1', '1', 'billing');
      await iOpenFromTheProjectsOfThisMachine(tester, 'checkout');
      await theRepositorySays(tester, 'billing', '1 of 1 task running');
      await theRepositoryDoesNotSay(tester, 'billing', 'no task running');
    });
  });
}
