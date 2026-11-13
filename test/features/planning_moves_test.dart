// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_planning.dart';
import './step/the_app_is_running.dart';
import './step/i_open_the_planning_board.dart';
import './step/i_search_planning_for.dart';
import './step/i_drag_planning_story_to.dart';
import './step/the_planning_save_sent_the_digest_its_preview_answered.dart';
import './step/no_planning_move_warning_is_shown.dart';
import './step/planning_story_is_not_being_saved.dart';
import './step/the_planning_story_is_in.dart';
import './step/planning_warns_that_carries_issues_along.dart';
import './step/no_planning_move_was_saved.dart';
import './step/i_confirm_the_planning_move.dart';
import './step/i_expand_planning_story_issues.dart';
import './step/advanced_planning_issues_keep_their_state.dart';
import './step/i_cancel_the_planning_move.dart';
import './step/the_planning_move_reply_is_held.dart';
import './step/planning_story_is_being_saved.dart';
import './step/the_planning_move_reply_arrives.dart';
import './step/no_planning_move_error_is_shown.dart';
import './step/the_planning_save_is_partly_saved_with_story_saved_in.dart';
import './step/the_planning_move_error_says.dart';
import './step/the_planning_revision_changes_on_the_machine.dart';
import './step/the_planning_machine_refuses_moves_with.dart';
import './step/i_reload_planning_moves.dart';
import './step/the_planning_save_refuses_for_story_with.dart';
import './step/the_planning_machine_refuses_story_with.dart';
import './step/the_planning_move_error_no_longer_says.dart';
import './step/i_fold_the_planning_phase.dart';
import './step/planning_start_was_requested_for_in.dart';
import './step/i_show_closed_planning_states.dart';
import './step/i_hold_planning_story_over.dart';
import './step/the_planning_drop_hint_names.dart';
import './step/i_drop_the_planning_story.dart';
import './step/no_planning_drop_hint_names.dart';
import './step/no_planning_start_is_requested.dart';
import './step/i_try_to_leave_planning_moves.dart';
import './step/planning_asks_to_wait_for_the_save.dart';
import './step/i_keep_editing_planning_moves.dart';
import './step/the_planning_page_is_shown.dart';
import './step/the_work_page_is_shown.dart';
import './step/i_ask_to_close_it.dart';
import './step/the_planning_window_close_is_canceled.dart';
import './step/the_planning_save_times_out.dart';
import './step/the_planning_move_notice_says.dart';
import './step/planning_asks_before_leaving.dart';
import './step/i_leave_planning_anyway.dart';
import './step/i_open_story_work_for.dart';
import './step/i_choose_story_work.dart';
import './step/planning_warns_that_moving_stops_its_running_work.dart';
import './step/nothing_was_stopped_on_this_machine.dart';
import './step/the_tasks_the_planning_save_stopped_were_stopped_on_this_machine.dart';

void main() {
  group('''Planning moves are saved at once''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithPlanning(tester);
      await theAppIsRunning(tester);
      await iOpenThePlanningBoard(tester);
      await iSearchPlanningFor(tester, 'ST29');
    }

    testWidgets('''A drop is previewed and saved at once''', (tester) async {
      await bddSetUp(tester);
      await iDragPlanningStoryTo(tester, 'ST293', 'Review');
      await thePlanningSaveSentTheDigestItsPreviewAnswered(tester);
      await noPlanningMoveWarningIsShown(tester);
      await planningStoryIsNotBeingSaved(tester, 'ST293');
      await thePlanningStoryIsIn(tester, 'ST293', 'Review');
    });
    testWidgets('''A move that carries issues along asks first and takes the daemon confirmation''', (tester) async {
      await bddSetUp(tester);
      await iDragPlanningStoryTo(tester, 'ST291', 'Review');
      await planningWarnsThatCarriesIssuesAlong(tester, 'ST291');
      await noPlanningMoveWasSaved(tester);
      await iConfirmThePlanningMove(tester);
      await noPlanningMoveWarningIsShown(tester);
      await planningStoryIsNotBeingSaved(tester, 'ST291');
      await thePlanningStoryIsIn(tester, 'ST291', 'Review');
      await iExpandPlanningStoryIssues(tester, 'ST291');
      await advancedPlanningIssuesKeepTheirState(tester);
    });
    testWidgets('''A canceled warning sends nothing''', (tester) async {
      await bddSetUp(tester);
      await iDragPlanningStoryTo(tester, 'ST291', 'Review');
      await iCancelThePlanningMove(tester);
      await noPlanningMoveWarningIsShown(tester);
      await noPlanningMoveWasSaved(tester);
      await planningStoryIsNotBeingSaved(tester, 'ST291');
      await thePlanningStoryIsIn(tester, 'ST291', 'Backlog');
    });
    testWidgets('''A move shows as saving until the planner answers''', (tester) async {
      await bddSetUp(tester);
      await thePlanningMoveReplyIsHeld(tester);
      await iDragPlanningStoryTo(tester, 'ST293', 'Review');
      await planningStoryIsBeingSaved(tester, 'ST293');
      await thePlanningMoveReplyArrives(tester);
      await planningStoryIsNotBeingSaved(tester, 'ST293');
      await thePlanningStoryIsIn(tester, 'ST293', 'Review');
    });
    testWidgets('''A saved move takes the planner's new revision for the next move''', (tester) async {
      await bddSetUp(tester);
      await iDragPlanningStoryTo(tester, 'ST293', 'Review');
      await iDragPlanningStoryTo(tester, 'ST293', 'Backlog');
      await noPlanningMoveErrorIsShown(tester);
      await planningStoryIsNotBeingSaved(tester, 'ST293');
      await thePlanningStoryIsIn(tester, 'ST293', 'Backlog');
    });
    testWidgets('''A partly saved move says so in the planner's words and reads the board again''', (tester) async {
      await bddSetUp(tester);
      await thePlanningSaveIsPartlySavedWithStorySavedIn(tester, 'ST293', 'Review');
      await iDragPlanningStoryTo(tester, 'ST293', 'Review');
      await thePlanningMoveErrorSays(
        tester,
        'The repository refused the push. Pushed: porelo. Not pushed: porelo-host.',
      );
      await planningStoryIsNotBeingSaved(tester, 'ST293');
      await thePlanningStoryIsIn(tester, 'ST293', 'Review');
    });
    testWidgets('''A stale revision moves nothing and the next move clears its feedback''', (tester) async {
      await bddSetUp(tester);
      await thePlanningRevisionChangesOnTheMachine(tester);
      await iDragPlanningStoryTo(tester, 'ST293', 'Review');
      await thePlanningMoveErrorSays(
        tester,
        'Planning changed while ST293 was moved; nothing was moved. Move it again.',
      );
      await planningStoryIsNotBeingSaved(tester, 'ST293');
      await thePlanningStoryIsIn(tester, 'ST293', 'Backlog');
      await iDragPlanningStoryTo(tester, 'ST293', 'Review');
      await noPlanningMoveErrorIsShown(tester);
      await thePlanningStoryIsIn(tester, 'ST293', 'Review');
    });
    testWidgets('''An unnamed refusal leaves the card where it stands with the daemon words''', (tester) async {
      await bddSetUp(tester);
      await thePlanningMachineRefusesMovesWith(tester, 'The board cannot be written');
      await iDragPlanningStoryTo(tester, 'ST293', 'Review');
      await thePlanningMoveErrorSays(tester, 'The board cannot be written');
      await planningStoryIsNotBeingSaved(tester, 'ST293');
      await thePlanningStoryIsIn(tester, 'ST293', 'Backlog');
      await iReloadPlanningMoves(tester);
      await thePlanningStoryIsIn(tester, 'ST293', 'Backlog');
    });
    testWidgets('''A refusal naming the story shows its words''', (tester) async {
      await bddSetUp(tester);
      await thePlanningSaveRefusesForStoryWith(tester, 'NoSuchStory', 'ST293', 'The story is unknown');
      await iDragPlanningStoryTo(tester, 'ST293', 'Review');
      await thePlanningMoveErrorSays(tester, 'The story is unknown');
      await planningStoryIsNotBeingSaved(tester, 'ST293');
      await thePlanningStoryIsIn(tester, 'ST293', 'Backlog');
    });
    testWidgets('''A refusal of one story leaves the next move free''', (tester) async {
      await bddSetUp(tester);
      await thePlanningMachineRefusesStoryWith(tester, 'ST291', 'Work is still running');
      await iDragPlanningStoryTo(tester, 'ST291', 'Review');
      await iConfirmThePlanningMove(tester);
      await thePlanningMoveErrorSays(tester, 'Work is still running');
      await thePlanningStoryIsIn(tester, 'ST291', 'Backlog');
      await iDragPlanningStoryTo(tester, 'ST293', 'Review');
      await noPlanningMoveErrorIsShown(tester);
      await thePlanningStoryIsIn(tester, 'ST293', 'Review');
      await thePlanningStoryIsIn(tester, 'ST291', 'Backlog');
    });
    testWidgets('''A new move clears the previous problem before showing its new refusal''', (tester) async {
      await bddSetUp(tester);
      await thePlanningMachineRefusesStoryWith(tester, 'ST293', 'Work is still running');
      await iDragPlanningStoryTo(tester, 'ST293', 'Review');
      await thePlanningMoveErrorSays(tester, 'Work is still running');
      await thePlanningSaveRefusesForStoryWith(tester, 'AnotherRefusal', 'ST293', 'This story cannot move');
      await iDragPlanningStoryTo(tester, 'ST293', 'Review');
      await thePlanningMoveErrorSays(tester, 'This story cannot move');
      await thePlanningMoveErrorNoLongerSays(tester, 'Work is still running');
      await thePlanningStoryIsIn(tester, 'ST293', 'Backlog');
    });
    testWidgets('''A refusal stays readable when its card is folded''', (tester) async {
      await bddSetUp(tester);
      await thePlanningMachineRefusesMovesWith(tester, 'Work is still running');
      await iDragPlanningStoryTo(tester, 'ST293', 'Review');
      await iFoldThePlanningPhase(tester, 'Backlog');
      await thePlanningMoveErrorSays(tester, 'Work is still running');
    });
    testWidgets('''A working state requests a start and moves nothing''', (tester) async {
      await bddSetUp(tester);
      await iDragPlanningStoryTo(tester, 'ST291', 'Implementing');
      await planningStartWasRequestedForIn(tester, 'ST291', 'Implementing');
      await noPlanningMoveErrorIsShown(tester);
      await noPlanningMoveWasSaved(tester);
      await thePlanningStoryIsIn(tester, 'ST291', 'Backlog');
    });
    testWidgets('''A closed destination accepts a drop''', (tester) async {
      await bddSetUp(tester);
      await iSearchPlanningFor(tester, 'ST293');
      await iShowClosedPlanningStates(tester);
      await iFoldThePlanningPhase(tester, 'Build');
      await iDragPlanningStoryTo(tester, 'ST293', 'Finished');
      await planningStoryIsNotBeingSaved(tester, 'ST293');
      await thePlanningStoryIsIn(tester, 'ST293', 'Finished');
    });
    testWidgets('''Hover names the destination''', (tester) async {
      await bddSetUp(tester);
      await iHoldPlanningStoryOver(tester, 'ST293', 'Review');
      await thePlanningDropHintNames(tester, 'Review');
      await iDropThePlanningStory(tester);
      await thePlanningStoryIsIn(tester, 'ST293', 'Review');
    });
    testWidgets('''A working card does not offer its own state as a destination''', (tester) async {
      await bddSetUp(tester);
      await iSearchPlanningFor(tester, 'ST27');
      await iHoldPlanningStoryOver(tester, 'ST27', 'Implementing');
      await noPlanningDropHintNames(tester, 'Implementing');
      await iDropThePlanningStory(tester);
      await noPlanningStartIsRequested(tester);
      await noPlanningMoveWasSaved(tester);
      await thePlanningStoryIsIn(tester, 'ST27', 'Implementing');
    });
    testWidgets('''Leaving Planning while a move is saved waits for the planner''', (tester) async {
      await bddSetUp(tester);
      await thePlanningMoveReplyIsHeld(tester);
      await iDragPlanningStoryTo(tester, 'ST293', 'Review');
      await iTryToLeavePlanningMoves(tester);
      await planningAsksToWaitForTheSave(tester);
      await iKeepEditingPlanningMoves(tester);
      await thePlanningPageIsShown(tester);
      await planningStoryIsBeingSaved(tester, 'ST293');
      await thePlanningMoveReplyArrives(tester);
      await iTryToLeavePlanningMoves(tester);
      await theWorkPageIsShown(tester);
    });
    testWidgets('''Closing the window while a move is saved asks first and can be canceled''', (tester) async {
      await bddSetUp(tester);
      await thePlanningMoveReplyIsHeld(tester);
      await iDragPlanningStoryTo(tester, 'ST293', 'Review');
      await iAskToCloseIt(tester);
      await planningAsksToWaitForTheSave(tester);
      await iKeepEditingPlanningMoves(tester);
      await thePlanningWindowCloseIsCanceled(tester);
      await planningStoryIsBeingSaved(tester, 'ST293');
    });
    testWidgets('''Window close keeps one existing planning question''', (tester) async {
      await bddSetUp(tester);
      await thePlanningMoveReplyIsHeld(tester);
      await iDragPlanningStoryTo(tester, 'ST293', 'Review');
      await iTryToLeavePlanningMoves(tester);
      await iAskToCloseIt(tester);
      await planningAsksToWaitForTheSave(tester);
      await iKeepEditingPlanningMoves(tester);
      await thePlanningPageIsShown(tester);
    });
    testWidgets('''A move the planner answers late can be left and is still awaited on the return''', (tester) async {
      await bddSetUp(tester);
      await thePlanningSaveTimesOut(tester);
      await iDragPlanningStoryTo(tester, 'ST293', 'Review');
      await thePlanningMoveNoticeSays(tester, 'Still saving.');
      await iTryToLeavePlanningMoves(tester);
      await planningAsksBeforeLeaving(tester);
      await iLeavePlanningAnyway(tester);
      await theWorkPageIsShown(tester);
      await iOpenThePlanningBoard(tester);
      await planningStoryIsBeingSaved(tester, 'ST293');
    });
    testWidgets('''A move over running work warns first and Cancel stops nothing''', (tester) async {
      await bddSetUp(tester);
      await iOpenStoryWorkFor(tester, 'ST291');
      await iChooseStoryWork(tester, 'start');
      await iDragPlanningStoryTo(tester, 'ST291', 'Review');
      await planningWarnsThatMovingStopsItsRunningWork(tester, 'ST291');
      await planningWarnsThatCarriesIssuesAlong(tester, 'ST291');
      await iCancelThePlanningMove(tester);
      await noPlanningMoveWarningIsShown(tester);
      await noPlanningMoveWasSaved(tester);
      await nothingWasStoppedOnThisMachine(tester);
      await thePlanningStoryIsIn(tester, 'ST291', 'Backlog');
    });
    testWidgets('''A confirmed move over running work ends exactly the tasks the planner stopped''', (tester) async {
      await bddSetUp(tester);
      await iOpenStoryWorkFor(tester, 'ST291');
      await iChooseStoryWork(tester, 'start');
      await iDragPlanningStoryTo(tester, 'ST291', 'Review');
      await planningWarnsThatMovingStopsItsRunningWork(tester, 'ST291');
      await iConfirmThePlanningMove(tester);
      await noPlanningMoveErrorIsShown(tester);
      await theTasksThePlanningSaveStoppedWereStoppedOnThisMachine(tester);
      await planningStoryIsNotBeingSaved(tester, 'ST291');
    });
  });
}
