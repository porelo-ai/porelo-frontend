// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_the_work.dart';
import './step/the_project_is_listed.dart';
import './step/the_status_line_mentions.dart';
import './step/i_select_the_project.dart';
import './step/the_work_is_listed.dart';
import './step/i_select_the_work.dart';
import './step/i_open_the_selection.dart';
import './step/the_detail_for_is_shown.dart';
import './step/i_move_the_keyboard_to_the_project.dart';
import './step/i_press_enter.dart';
import './step/the_project_is_selected.dart';
import './step/i_close_what_is_open.dart';
import './step/the_work_pane_is_shown.dart';
import './step/the_work_is_still_selected.dart';
import './step/i_open_the_command_finder.dart';
import './step/the_command_finder_names.dart';
import './step/the_command_is_offered_as_unavailable.dart';
import './step/i_open_the_menu.dart';
import './step/i_choose_the_menu_entry.dart';
import './step/the_appearance_is.dart';
import './step/i_choose_the_command.dart';
import './step/the_app_is_restarted.dart';
import './step/the_window_is_pixels_wide.dart';
import './step/the_rail_is_shown.dart';
import './step/i_open_the_machines.dart';
import './step/i_pick_in_the_finder.dart';
import './step/the_menu_that_holds_is_open_with_it_marked.dart';
import './step/the_title_is.dart';
import './step/i_go_to_the_place.dart';
import './step/the_tunnel_drops.dart';
import './step/the_command_is_unavailable_because.dart';
import './step/enough_time_passes_for_another_try.dart';
import './step/nothing_answers_on_that_machine.dart';
import './step/it_says.dart';
import './step/i_agree_to_start_it.dart';
import './step/the_machine_was_asked_to_start.dart';
import './step/following_a_repository_on_this_machine_is_not_offered.dart';
import './step/stopping_everything_everywhere_is_not_offered.dart';
import './step/stopping_everything_everywhere_is_offered.dart';

void main() {
  group('''Moving around the frame by keyboard and by pointer''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await iGoToTheWork(tester);
    }

    testWidgets('''what is on the machine is answered before anything is selected''', (tester) async {
      await bddSetUp(tester);
      await theProjectIsListed(tester, 'checkout');
      await theProjectIsListed(tester, 'billing');
      await theStatusLineMentions(tester, 'Connected');
    });
    testWidgets('''a project and its work are each one selection away''', (tester) async {
      await bddSetUp(tester);
      await iSelectTheProject(tester, 'checkout');
      await theWorkIsListed(tester, 'porelo-checkout-shell');
      await iSelectTheWork(tester, 'porelo-checkout-shell');
      await iOpenTheSelection(tester);
      await theDetailForIsShown(tester, 'porelo-checkout-shell');
    });
    testWidgets('''the frame is worked from the keyboard with no pointer at all''', (tester) async {
      await bddSetUp(tester);
      await iMoveTheKeyboardToTheProject(tester, 'billing');
      await iPressEnter(tester);
      await theProjectIsSelected(tester, 'billing');
    });
    testWidgets('''closing a detail comes back with the same selection still made''', (tester) async {
      await bddSetUp(tester);
      await iSelectTheProject(tester, 'checkout');
      await iSelectTheWork(tester, 'porelo-checkout-shell');
      await iOpenTheSelection(tester);
      await iCloseWhatIsOpen(tester);
      await theWorkPaneIsShown(tester);
      await theWorkIsStillSelected(tester, 'porelo-checkout-shell');
      await theProjectIsSelected(tester, 'checkout');
    });
    testWidgets('''one finder names actions belonging to a screen that is not open''', (tester) async {
      await bddSetUp(tester);
      await iOpenTheCommandFinder(tester);
      await theCommandFinderNames(tester, 'Refresh from the backend');
      await theCommandFinderNames(tester, 'Open the selected work');
      await theCommandIsOfferedAsUnavailable(tester, 'Open the selected work');
    });
    testWidgets('''every action is reachable with a pointer alone''', (tester) async {
      await bddSetUp(tester);
      await iOpenTheMenu(tester, 'Options');
      await iChooseTheMenuEntry(tester, 'Appearance: dark');
      await theAppearanceIs(tester, 'dark');
    });
    testWidgets('''the status line says in words what the last action did''', (tester) async {
      await bddSetUp(tester);
      await iChooseTheCommand(tester, 'Refresh from the backend');
      await theStatusLineMentions(tester, 'Refreshed');
    });
    testWidgets('''appearance is a choice and it survives a restart''', (tester) async {
      await bddSetUp(tester);
      await iChooseTheCommand(tester, 'Appearance: dark');
      await theAppearanceIs(tester, 'dark');
      await theAppIsRestarted(tester);
      await theAppearanceIs(tester, 'dark');
    });
    testWidgets('''a narrow window keeps the rail behind the menu button''', (tester) async {
      await bddSetUp(tester);
      await theWindowIsPixelsWide(tester, 420);
      await theRailIsShown(tester, false);
      await iOpenTheMachines(tester);
      await theRailIsShown(tester, true);
    });
    testWidgets('''the finder goes to where an action lives and marks it there''', (tester) async {
      await bddSetUp(tester);
      await iOpenTheCommandFinder(tester);
      await iPickInTheFinder(tester, 'Check whether this machine can run anything');
      await theMenuThatHoldsIsOpenWithItMarked(tester, 'Check whether this machine can run anything');
    });
    testWidgets('''the title says where you are''', (tester) async {
      await bddSetUp(tester);
      await theTitleIs(tester, 'this machine');
      await iSelectTheProject(tester, 'checkout');
      await theTitleIs(tester, 'this machine › checkout');
      await iGoToThePlace(tester, 'work');
      await theTitleIs(tester, 'Work');
    });
    testWidgets('''a machine that does not answer offers nothing that needs it, and says why''', (tester) async {
      await bddSetUp(tester);
      await iSelectTheProject(tester, 'checkout');
      await theTunnelDrops(tester);
      await iOpenTheCommandFinder(tester);
      await theCommandIsUnavailableBecause(tester, 'Follow a project', 'not answering');
      await theCommandIsUnavailableBecause(tester, 'Build the environment for this project', 'not answering');
      await iCloseWhatIsOpen(tester);
      await enoughTimePassesForAnotherTry(tester);
    });
    testWidgets('''checking a machine that does not answer offers to start Porelo there first''', (tester) async {
      await bddSetUp(tester);
      await nothingAnswersOnThatMachine(tester);
      await theTunnelDrops(tester);
      await iChooseTheCommand(tester, 'Check whether this machine can run anything');
      await itSays(tester, 'Start Porelo on this computer?');
      await itSays(tester, 'This starts the daemon here, as you.');
      await iAgreeToStartIt(tester);
      await theMachineWasAskedToStart(tester, 'systemctl --user');
      await itSays(tester, 'What this machine can run');
    }, tags: ['linux']);
    testWidgets('''following a repository and the stop for every machine wait for a machine that answers''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theTunnelDrops(tester);
      await followingARepositoryOnThisMachineIsNotOffered(tester);
      await stoppingEverythingEverywhereIsNotOffered(tester);
      await enoughTimePassesForAnotherTry(tester);
      await stoppingEverythingEverywhereIsOffered(tester);
    });
  });
}
