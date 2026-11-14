// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_planning.dart';
import './step/the_app_is_running.dart';
import './step/i_open_the_planning_board.dart';
import './step/the_planning_story_is_in.dart';
import './step/the_planning_phases_follow_the_workflow.dart';
import './step/the_planning_states_put_working_states_first.dart';
import './step/the_planning_state_is_renamed_on_the_machine.dart';
import './step/the_old_planning_state_is_absent.dart';
import './step/the_planning_build_stories_are_sorted.dart';
import './step/i_fold_the_planning_phase.dart';
import './step/the_folded_planning_build_retains_its_count_and_marks.dart';
import './step/closed_planning_states_start_folded.dart';
import './step/i_unfold_closed_planning_states.dart';
import './step/closed_planning_states_are_shown.dart';
import './step/the_machine_moves_a_planning_story.dart';
import './step/the_moved_planning_story_is_absent_from_backlog.dart';
import './step/the_machine_has_no_planning.dart';
import './step/the_machine_does_not_offer_planning.dart';
import './step/the_planning_watch_fails.dart';
import './step/the_planning_error_says.dart';
import './step/the_planning_watch_ends.dart';
import './step/i_filter_planning_to_high_and_above.dart';
import './step/low_priority_planning_stories_are_hidden.dart';
import './step/i_search_planning_for.dart';
import './step/only_the_searched_planning_story_remains.dart';
import './step/the_window_is_pixels_wide.dart';
import './step/the_planning_search_is_reachable.dart';
import './step/another_machine_offers_the_same_project_planning.dart';
import './step/the_other_planning_provider_supplies_the_board.dart';
import './step/i_reload_planning.dart';
import './step/the_machine_reports_issues_in_reading_and_reworking.dart';
import './step/the_planning_story_shows_reading.dart';
import './step/the_machine_reports_a_stopped_reading.dart';
import './step/the_planning_reading_of_needs_attention.dart';
import './step/i_press_the_planning_reading_of.dart';
import './step/the_section_shown_is.dart';
import './step/the_machine_reports_a_stopped_run_of.dart';
import './step/i_go_to_what_needs_a_person.dart';
import './step/the_needs_you_row_of_offers_to_start_again.dart';

void main() {
  group('''The stories of a project on a planning board''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithPlanning(tester);
      await theAppIsRunning(tester);
    }

    testWidgets('''A story stands in the state the machine reports''', (tester) async {
      await bddSetUp(tester);
      await iOpenThePlanningBoard(tester);
      await thePlanningStoryIsIn(tester, 'ST291', 'Backlog');
      await thePlanningPhasesFollowTheWorkflow(tester);
      await thePlanningStatesPutWorkingStatesFirst(tester);
    });
    testWidgets('''A renamed state arrives with its stories''', (tester) async {
      await bddSetUp(tester);
      await iOpenThePlanningBoard(tester);
      await thePlanningStateIsRenamedOnTheMachine(tester);
      await thePlanningStoryIsIn(tester, 'ST294', 'Investigating');
      await theOldPlanningStateIsAbsent(tester);
    });
    testWidgets('''Stories sort by priority and then their number''', (tester) async {
      await bddSetUp(tester);
      await iOpenThePlanningBoard(tester);
      await thePlanningBuildStoriesAreSorted(tester);
    });
    testWidgets('''A folded phase retains its count and priority marks''', (tester) async {
      await bddSetUp(tester);
      await iOpenThePlanningBoard(tester);
      await iFoldThePlanningPhase(tester, 'Build');
      await theFoldedPlanningBuildRetainsItsCountAndMarks(tester);
    });
    testWidgets('''Closed states can be revealed''', (tester) async {
      await bddSetUp(tester);
      await iOpenThePlanningBoard(tester);
      await closedPlanningStatesStartFolded(tester);
      await iUnfoldClosedPlanningStates(tester);
      await closedPlanningStatesAreShown(tester);
    });
    testWidgets('''A changed watch answer replaces the board without reload''', (tester) async {
      await bddSetUp(tester);
      await iOpenThePlanningBoard(tester);
      await theMachineMovesAPlanningStory(tester);
      await thePlanningStoryIsIn(tester, 'ST291', 'Review');
      await theMovedPlanningStoryIsAbsentFromBacklog(tester);
    });
    testWidgets('''An older machine does not offer planning''', (tester) async {
      await bddSetUp(tester);
      await theMachineHasNoPlanning(tester);
      await iOpenThePlanningBoard(tester);
      await theMachineDoesNotOfferPlanning(tester);
    });
    testWidgets('''A watch failure is shown in the machine words''', (tester) async {
      await bddSetUp(tester);
      await iOpenThePlanningBoard(tester);
      await thePlanningWatchFails(tester);
      await thePlanningErrorSays(tester, 'Planning store cannot be read');
    });
    testWidgets('''An ended single-answer watch keeps its board''', (tester) async {
      await bddSetUp(tester);
      await iOpenThePlanningBoard(tester);
      await thePlanningWatchEnds(tester);
      await thePlanningStoryIsIn(tester, 'ST291', 'Backlog');
    });
    testWidgets('''Priority and search narrow the board''', (tester) async {
      await bddSetUp(tester);
      await iOpenThePlanningBoard(tester);
      await iFilterPlanningToHighAndAbove(tester);
      await lowPriorityPlanningStoriesAreHidden(tester);
      await iSearchPlanningFor(tester, 'ST291');
      await onlyTheSearchedPlanningStoryRemains(tester);
    });
    testWidgets('''Planning remains usable in a narrow window''', (tester) async {
      await bddSetUp(tester);
      await iOpenThePlanningBoard(tester);
      await theWindowIsPixelsWide(tester, 390);
      await thePlanningSearchIsReachable(tester);
    });
    testWidgets('''A live provider supplies the board when the preferred watch fails''', (tester) async {
      await bddSetUp(tester);
      await anotherMachineOffersTheSameProjectPlanning(tester);
      await iOpenThePlanningBoard(tester);
      await thePlanningWatchFails(tester);
      await theOtherPlanningProviderSuppliesTheBoard(tester);
    });
    testWidgets('''Planning can be retried while the machine stays connected''', (tester) async {
      await bddSetUp(tester);
      await iOpenThePlanningBoard(tester);
      await thePlanningWatchFails(tester);
      await iReloadPlanning(tester);
      await theMachineMovesAPlanningStory(tester);
      await thePlanningStoryIsIn(tester, 'ST291', 'Review');
    });
    testWidgets('''Reading rounds come from the machine for Reading and Reworking''', (tester) async {
      await bddSetUp(tester);
      await iOpenThePlanningBoard(tester);
      await theMachineReportsIssuesInReadingAndReworking(tester);
      await thePlanningStoryShowsReading(tester, 'ST291', '2 of 5, 4 of 7');
    });
    testWidgets('''Stopped reading leads to Needs you''', (tester) async {
      await bddSetUp(tester);
      await iOpenThePlanningBoard(tester);
      await theMachineReportsAStoppedReading(tester);
      await thePlanningReadingOfNeedsAttention(tester, 'ST291');
      await iPressThePlanningReadingOf(tester, 'ST291');
      await theSectionShownIs(tester, 'Needs you');
    });
    testWidgets('''A stopped story's row in Needs you offers to start again''', (tester) async {
      await bddSetUp(tester);
      await theMachineReportsAStoppedRunOf(tester, 'ST291');
      await iGoToWhatNeedsAPerson(tester);
      await theNeedsYouRowOfOffersToStartAgain(tester, 'B540');
    });
  });
}
