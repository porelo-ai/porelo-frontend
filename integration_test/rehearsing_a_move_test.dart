// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import './step/the_interface_is_running.dart';
import './step/the_rehearsal_names_its_host_and_project.dart';
import './step/i_connect_the_host_from_the_organization.dart';
import './step/the_host_is_answering_through_the_window.dart';
import './step/i_open_the_organizations_machines.dart';
import './step/the_host_is_listed_there_with_the_project.dart';
import './step/the_host_is_connected_from_the_organization.dart';
import './step/i_open_the_project_on_the_host.dart';
import './step/each_repository_of_the_project_says_whether_the_host_carries_it_as_the_host_says.dart';
import './step/i_start_work_on_the_first_carried_repository_of_the_project.dart';
import './step/the_host_runs_that_work_under_the_name_and_model_the_window_showed.dart';
import './step/i_start_work_on_every_repository_of_the_project_at_once.dart';
import './step/the_host_runs_one_task_for_each_carried_repository.dart';
import './step/a_task_of_the_project_on_the_host_has_work_waiting_at_its_gate.dart';
import './step/i_review_that_work_at_the_gate.dart';
import './step/the_review_names_its_commit_and_who_made_it.dart';
import './step/i_forward_it_to_a_new_branch_of_the_rehearsal.dart';
import './step/the_hosts_forge_has_that_branch_at_the_reviewed_commit.dart';
import './step/the_tasks_tile_says_how_its_builds_stand_as_the_hosts_runner_says.dart';
import './step/i_open_the_hosts_page_in_the_organization.dart';
import './step/the_key_it_shows_is_the_one_read_from_the_server_as_root.dart';
import './step/i_sign_in_to_the_agent_of_the_first_carried_repository_from_new_work.dart';
import './step/the_terminal_shows_the_providers_link.dart';
import './step/i_close_the_terminal.dart';
import './step/the_hosts_login_of_that_agent_still_runs.dart';
import './step/the_gathered_push_to_central_is_said_not_to_run_yet_with_why.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('''A move rehearsed in the window against a rented host''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await theInterfaceIsRunning(tester);
      await theRehearsalNamesItsHostAndProject(tester);
    }

    testWidgets('''the host the organization lists is connected from its card''', (tester) async {
      await bddSetUp(tester);
      await iConnectTheHostFromTheOrganization(tester);
      await theHostIsAnsweringThroughTheWindow(tester);
    });
    testWidgets('''the organization's machines list the host with the project it carries''', (tester) async {
      await bddSetUp(tester);
      await iOpenTheOrganizationsMachines(tester);
      await theHostIsListedThereWithTheProject(tester);
    });
    testWidgets('''the project on the host names each repository as the host carries it''', (tester) async {
      await bddSetUp(tester);
      await theHostIsConnectedFromTheOrganization(tester);
      await iOpenTheProjectOnTheHost(tester);
      await eachRepositoryOfTheProjectSaysWhetherTheHostCarriesItAsTheHostSays(tester);
    });
    testWidgets('''work started from the project on the host runs there, named and with its model''', (tester) async {
      await bddSetUp(tester);
      await theHostIsConnectedFromTheOrganization(tester);
      await iStartWorkOnTheFirstCarriedRepositoryOfTheProject(tester);
      await theHostRunsThatWorkUnderTheNameAndModelTheWindowShowed(tester);
    });
    testWidgets('''a start for every repository makes one task each and asks no sign-in twice''', (tester) async {
      await bddSetUp(tester);
      await theHostIsConnectedFromTheOrganization(tester);
      await iStartWorkOnEveryRepositoryOfTheProjectAtOnce(tester);
      await theHostRunsOneTaskForEachCarriedRepository(tester);
    });
    testWidgets('''a task's push is reviewed, forwarded to the host's forge and built there''', (tester) async {
      await bddSetUp(tester);
      await theHostIsConnectedFromTheOrganization(tester);
      await aTaskOfTheProjectOnTheHostHasWorkWaitingAtItsGate(tester);
      await iReviewThatWorkAtTheGate(tester);
      await theReviewNamesItsCommitAndWhoMadeIt(tester);
      await iForwardItToANewBranchOfTheRehearsal(tester);
      await theHostsForgeHasThatBranchAtTheReviewedCommit(tester);
      await theTasksTileSaysHowItsBuildsStandAsTheHostsRunnerSays(tester);
    });
    testWidgets('''the host's key the organization holds is the one the server has''', (tester) async {
      await bddSetUp(tester);
      await theHostIsConnectedFromTheOrganization(tester);
      await iOpenTheHostsPageInTheOrganization(tester);
      await theKeyItShowsIsTheOneReadFromTheServerAsRoot(tester);
    });
    testWidgets('''an agent's sign-in goes on on the host after its terminal is closed''', (tester) async {
      await bddSetUp(tester);
      await theHostIsConnectedFromTheOrganization(tester);
      await iSignInToTheAgentOfTheFirstCarriedRepositoryFromNewWork(tester);
      await theTerminalShowsTheProvidersLink(tester);
      await iCloseTheTerminal(tester);
      await theHostsLoginOfThatAgentStillRuns(tester);
    });
    testWidgets('''the gathered push to central''', (tester) async {
      await bddSetUp(tester);
      await theGatheredPushToCentralIsSaidNotToRunYetWithWhy(tester);
    });
  });
}
