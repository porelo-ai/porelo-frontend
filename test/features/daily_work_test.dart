// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_app_is_running.dart';
import './step/the_section_shown_is.dart';
import './step/the_work_is_in_the_group.dart';
import './step/the_work_has_stopped.dart';
import './step/the_group_is_shut.dart';
import './step/i_open_the_group.dart';
import './step/the_tile_is_folded.dart';
import './step/i_open_the_tile.dart';
import './step/the_work_has_been_in_its_state_since.dart';
import './step/the_work_comes_before.dart';
import './step/i_narrow_the_work_to_the_project.dart';
import './step/no_tile_is_shown_for.dart';
import './step/i_narrow_the_work_to_every_project.dart';
import './step/i_start_new_work.dart';
import './step/i_choose_the_project_for_it.dart';
import './step/it_says.dart';
import './step/i_choose_no_project_for_it.dart';
import './step/i_go_to_the_place.dart';
import './step/the_project_is_listed.dart';
import './step/the_projects_page_lists_on.dart';
import './step/i_open_on_from_the_projects_page.dart';
import './step/the_project_is_the_one_shown.dart';
import './step/the_project_has_a_conversation_over_reaching_ready.dart';
import './step/the_machine_runs_work_of.dart';
import './step/i_start_new_work_on_in.dart';
import './step/it_does_not_say.dart';
import './step/i_choose_from_the_menu_of_the_tile.dart';
import './step/i_put_in_its_inbox.dart';
import './step/the_status_line_mentions.dart';
import './step/i_press.dart';
import './step/removing_will_refuse_because_the_work_is_held.dart';
import './step/what_is_held_is_shown.dart';
import './step/i_choose.dart';
import './step/the_machines_page_lists_only_machines.dart';
import './step/i_open_the_details_of.dart';
import './step/the_title_is.dart';
import './step/no_work_is_shown_on_this_page.dart';
import './step/i_select_the_project.dart';
import './step/i_go_to_its_work.dart';
import './step/i_watch_another_machine_called.dart';
import './step/i_remove_from_the_list_of_machines.dart';
import './step/the_machine_is_listed.dart';
import './step/the_machine_no_longer_has_the_project.dart';
import './step/the_machine_can_be_removed_from_the_list.dart';
import './step/i_choose_from_the_menu_of_the_project.dart';
import './step/the_project_is_marked_as_silent.dart';
import './step/the_projects_page_offers.dart';
import './step/the_machines_bar_is_shown.dart';
import './step/the_card_of_lists_the_machines.dart';

void main() {
  group('''Daily work in front, setting up machines and projects apart''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
    }

    testWidgets(
        '''the window opens on the work of every machine, what waits for a person first''',
        (tester) async {
      await bddSetUp(tester);
      await theSectionShownIs(tester, 'Work');
      await theWorkIsInTheGroup(tester, 'porelo-checkout-migrate', 'waiting');
      await theWorkIsInTheGroup(tester, 'porelo-checkout-shell', 'running');
      await theWorkIsInTheGroup(tester, 'porelo-billing-shell', 'running');
    });
    testWidgets('''stopped work is shown apart, its group shut until opened''',
        (tester) async {
      await bddSetUp(tester);
      await theWorkHasStopped(tester, 'porelo-billing-shell');
      await theGroupIsShut(tester, 'stopped', true);
      await iOpenTheGroup(tester, 'stopped');
      await theWorkIsInTheGroup(tester, 'porelo-billing-shell', 'stopped');
    });
    testWidgets(
        '''a tile on the work page is folded to its work and machine, and opened for the rest''',
        (tester) async {
      await bddSetUp(tester);
      await theTileIsFolded(tester, 'porelo-billing-shell', true);
      await iOpenTheTile(tester, 'porelo-billing-shell');
      await theTileIsFolded(tester, 'porelo-billing-shell', false);
    });
    testWidgets('''a tile that asks something of a person is never folded''',
        (tester) async {
      await bddSetUp(tester);
      await theTileIsFolded(tester, 'porelo-checkout-migrate', false);
    });
    testWidgets(
        '''the work in a group is in the order of its last activity, newest first''',
        (tester) async {
      await bddSetUp(tester);
      await theWorkHasBeenInItsStateSince(
          tester, 'porelo-billing-shell', '2026-10-03T08:00:00Z');
      await theWorkHasBeenInItsStateSince(
          tester, 'porelo-checkout-shell', '2026-10-01T08:00:00Z');
      await theWorkComesBefore(
          tester, 'porelo-billing-shell', 'porelo-checkout-shell');
    });
    testWidgets('''the work is narrowed to one project, and widened back''',
        (tester) async {
      await bddSetUp(tester);
      await iNarrowTheWorkToTheProject(tester, 'billing');
      await noTileIsShownFor(tester, 'porelo-checkout-shell');
      await theWorkIsInTheGroup(tester, 'porelo-billing-shell', 'running');
      await iNarrowTheWorkToEveryProject(tester);
      await theWorkIsInTheGroup(tester, 'porelo-checkout-shell', 'running');
    });
    testWidgets(
        '''new work asks in which project, and opens the start for it''',
        (tester) async {
      await bddSetUp(tester);
      await iStartNewWork(tester);
      await iChooseTheProjectForIt(tester, 'billing');
      await itSays(tester, 'Start work in billing');
    });
    testWidgets('''new work can be in no project''', (tester) async {
      await bddSetUp(tester);
      await iStartNewWork(tester);
      await iChooseNoProjectForIt(tester);
      await itSays(tester, 'Start work without a project');
    });
    testWidgets(
        '''machines are a page of setting up, each with its projects under it''',
        (tester) async {
      await bddSetUp(tester);
      await iGoToThePlace(tester, 'machines');
      await theSectionShownIs(tester, 'Machines');
      await theProjectIsListed(tester, 'checkout');
      await theProjectIsListed(tester, 'billing');
    });
    testWidgets(
        '''projects are a page of setting up, each opened on its machine''',
        (tester) async {
      await bddSetUp(tester);
      await iGoToThePlace(tester, 'projects');
      await theProjectsPageListsOn(tester, 'checkout', 'this machine');
      await iOpenOnFromTheProjectsPage(tester, 'billing', 'this machine');
      await theProjectIsTheOneShown(tester, 'billing');
    });
    testWidgets(
        '''starting work of a project that runs on another machine says they cannot talk''',
        (tester) async {
      await bddSetUp(tester);
      await theProjectHasAConversationOverReachingReady(
          tester, 'checkout', 'matrix', '127.0.0.1:8008');
      await theMachineRunsWorkOf(tester, 'elsewhere', 'checkout');
      await iStartNewWorkOnIn(tester, 'this machine', 'checkout');
      await itSays(tester, 'Work of checkout runs on elsewhere already');
      await itSays(tester,
          'only through a central Matrix server, and this project names none');
    });
    testWidgets(
        '''a project on a central server is said not to be joined by a second machine yet''',
        (tester) async {
      await bddSetUp(tester);
      await theProjectHasAConversationOverReachingReady(
          tester, 'checkout', 'matrix', 'https://matrix.example.org');
      await theMachineRunsWorkOf(tester, 'elsewhere', 'checkout');
      await iStartNewWorkOnIn(tester, 'this machine', 'checkout');
      await itSays(tester, 'a second machine cannot join it yet');
    });
    testWidgets(
        '''a project without a conversation says nothing about another machine''',
        (tester) async {
      await bddSetUp(tester);
      await theMachineRunsWorkOf(tester, 'elsewhere', 'checkout');
      await iStartNewWorkOnIn(tester, 'this machine', 'checkout');
      await itDoesNotSay(tester, 'runs on elsewhere already');
    });
    testWidgets(
        '''what an action from a tile answers is said on the work page''',
        (tester) async {
      await bddSetUp(tester);
      await iChooseFromTheMenuOfTheTile(
          tester, 'Write to its agent', 'porelo-checkout-migrate');
      await iPutInItsInbox(tester, 'the schema changed');
      await theSectionShownIs(tester, 'Work');
      await theStatusLineMentions(
          tester, 'Written into the inbox of porelo-checkout-migrate');
    });
    testWidgets(
        '''the order follows the last activity, whichever work it was''',
        (tester) async {
      await bddSetUp(tester);
      await theWorkHasBeenInItsStateSince(
          tester, 'porelo-checkout-shell', '2026-10-03T08:00:00Z');
      await theWorkHasBeenInItsStateSince(
          tester, 'porelo-billing-shell', '2026-10-01T08:00:00Z');
      await theWorkComesBefore(
          tester, 'porelo-checkout-shell', 'porelo-billing-shell');
    });
    testWidgets('''removing stopped work counts it out of its group''',
        (tester) async {
      await bddSetUp(tester);
      await theWorkHasStopped(tester, 'porelo-billing-shell');
      await theWorkHasStopped(tester, 'porelo-billing-audit');
      await iOpenTheGroup(tester, 'stopped');
      await itSays(tester, 'Stopped (2)');
      await iChooseFromTheMenuOfTheTile(
          tester, 'Remove it', 'porelo-billing-shell');
      await iPress(tester, 'Remove it');
      await itSays(tester, 'Stopped (1)');
    });
    testWidgets(
        '''a removal the machine refuses is put in front of the person on the work page''',
        (tester) async {
      await bddSetUp(tester);
      await theWorkHasStopped(tester, 'porelo-billing-shell');
      await removingWillRefuseBecauseTheWorkIsHeld(tester);
      await iOpenTheGroup(tester, 'stopped');
      await iChooseFromTheMenuOfTheTile(
          tester, 'Remove it', 'porelo-billing-shell');
      await iPress(tester, 'Remove it');
      await whatIsHeldIsShown(tester);
      await iChoose(tester, 'Leave it alone');
      await theGroupIsShut(tester, 'stopped', false);
    });
    testWidgets(
        '''machines are a list, and a machine's details show no projects and no work''',
        (tester) async {
      await bddSetUp(tester);
      await theMachinesPageListsOnlyMachines(tester);
      await iOpenTheDetailsOf(tester, 'this machine');
      await theTitleIs(tester, 'this machine');
      await noWorkIsShownOnThisPage(tester);
    });
    testWidgets(
        '''a project's page shows no work, and leads to its work on the work page''',
        (tester) async {
      await bddSetUp(tester);
      await iSelectTheProject(tester, 'billing');
      await theTitleIs(tester, 'this machine › billing');
      await noWorkIsShownOnThisPage(tester);
      await iGoToItsWork(tester);
      await theSectionShownIs(tester, 'Work');
      await noTileIsShownFor(tester, 'porelo-checkout-shell');
      await theWorkIsInTheGroup(tester, 'porelo-billing-shell', 'running');
    });
    testWidgets('''removing a machine from the list stays on the list''',
        (tester) async {
      await bddSetUp(tester);
      await iWatchAnotherMachineCalled(tester, 'elsewhere');
      await iRemoveFromTheListOfMachines(tester, 'elsewhere');
      await theSectionShownIs(tester, 'Machines');
      await theMachineIsListed(tester, 'elsewhere', false);
    });
    testWidgets(
        '''a project's page whose project went goes back to the list of projects''',
        (tester) async {
      await bddSetUp(tester);
      await iSelectTheProject(tester, 'billing');
      await theMachineNoLongerHasTheProject(tester, 'billing');
      await theSectionShownIs(tester, 'Projects');
    });
    testWidgets(
        '''this computer cannot be removed from the list of machines, another can''',
        (tester) async {
      await bddSetUp(tester);
      await iWatchAnotherMachineCalled(tester, 'elsewhere');
      await theMachineCanBeRemovedFromTheList(tester, 'this machine', false);
      await theMachineCanBeRemovedFromTheList(tester, 'elsewhere', true);
    });
    testWidgets(
        '''a project's row carries its menu, and its page the points to change it''',
        (tester) async {
      await bddSetUp(tester);
      await iGoToThePlace(tester, 'projects');
      await iChooseFromTheMenuOfTheProject(
          tester, 'Stop telling me about this project', 'checkout');
      await theProjectIsMarkedAsSilent(tester, 'checkout');
      await iSelectTheProject(tester, 'checkout');
      await theProjectsPageOffers(
          tester, 'Show what this project would open, creating nothing');
      await theProjectsPageOffers(tester, 'What this project may reach');
    });
    testWidgets(
        '''a project's page shows the project, not a bar of its machine''',
        (tester) async {
      await bddSetUp(tester);
      await iSelectTheProject(tester, 'billing');
      await theMachinesBarIsShown(tester, false);
      await iOpenTheDetailsOf(tester, 'this machine');
      await theMachinesBarIsShown(tester, true);
    });
    testWidgets(
        '''a project on two machines is listed once, saying both, and its page chooses between them''',
        (tester) async {
      await bddSetUp(tester);
      await theMachineRunsWorkOf(tester, 'elsewhere', 'checkout');
      await iGoToThePlace(tester, 'projects');
      await theCardOfListsTheMachines(
          tester, 'checkout', 'this machine, elsewhere');
      await iOpenOnFromTheProjectsPage(tester, 'checkout', 'elsewhere');
      await theTitleIs(tester, 'elsewhere › checkout');
    });
  });
}
