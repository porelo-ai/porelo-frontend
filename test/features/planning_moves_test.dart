// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_planning.dart';
import './step/the_app_is_running.dart';
import './step/i_open_the_planning_board.dart';
import './step/i_search_planning_for.dart';
import './step/i_drag_planning_story_to.dart';
import './step/the_planning_story_is_in.dart';
import './step/planning_story_has_a_pending_move.dart';
import './step/i_undo_planning_story.dart';
import './step/planning_story_has_no_pending_move.dart';
import './step/i_save_planning_moves.dart';
import './step/i_expand_planning_story_issues.dart';
import './step/advanced_planning_issues_keep_their_state.dart';
import './step/the_planning_revision_changes_on_the_machine.dart';
import './step/the_planning_move_notice_says.dart';
import './step/planning_save_is_usable.dart';
import './step/the_planning_machine_refuses_moves_with.dart';
import './step/planning_story_shows_refusal.dart';
import './step/planning_story_is_not_marked_moved.dart';
import './step/i_reload_planning_moves.dart';
import './step/planning_start_was_requested_for_in.dart';
import './step/no_planning_move_error_is_shown.dart';
import './step/i_show_closed_planning_states.dart';
import './step/i_try_to_leave_planning_moves.dart';
import './step/planning_asks_before_leaving.dart';
import './step/i_keep_editing_planning_moves.dart';
import './step/the_planning_page_is_shown.dart';
import './step/i_ask_to_close_it.dart';
import './step/the_planning_window_close_is_canceled.dart';
import './step/i_leave_planning_moves_pending.dart';
import './step/the_work_page_is_shown.dart';
import './step/i_hold_planning_story_over.dart';
import './step/the_planning_drop_hint_names.dart';
import './step/i_drop_the_planning_story.dart';
import './step/planning_story_is_marked_moved.dart';
import './step/i_undo_all_planning_moves.dart';
import './step/the_planning_machine_refuses_story_with.dart';
import './step/i_fold_the_planning_phase.dart';
import './step/the_planning_save_refuses_for_story_with.dart';
import './step/planning_story_no_longer_shows_refusal.dart';
import './step/no_planning_move_notice_is_shown.dart';
import './step/no_planning_drop_hint_names.dart';
import './step/no_planning_start_is_requested.dart';

void main() {
  group('''Planning moves stay pending until saved''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithPlanning(tester);
      await theAppIsRunning(tester);
      await iOpenThePlanningBoard(tester);
      await iSearchPlanningFor(tester, 'ST29');
    }

    testWidgets('''Drag and undo without writing to the machine''', (tester) async {
      await bddSetUp(tester);
      await iDragPlanningStoryTo(tester, 'ST291', 'Review');
      await thePlanningStoryIsIn(tester, 'ST291', 'Review');
      await planningStoryHasAPendingMove(tester, 'ST291');
      await iUndoPlanningStory(tester, 'ST291');
      await thePlanningStoryIsIn(tester, 'ST291', 'Backlog');
      await planningStoryHasNoPendingMove(tester, 'ST291');
    });
    testWidgets('''Undo one of several pending moves''', (tester) async {
      await bddSetUp(tester);
      await iDragPlanningStoryTo(tester, 'ST291', 'Review');
      await iDragPlanningStoryTo(tester, 'ST292', 'Review');
      await iUndoPlanningStory(tester, 'ST291');
      await thePlanningStoryIsIn(tester, 'ST291', 'Backlog');
      await planningStoryHasNoPendingMove(tester, 'ST291');
      await planningStoryHasAPendingMove(tester, 'ST292');
      await thePlanningStoryIsIn(tester, 'ST292', 'Review');
    });
    testWidgets('''Save uses the daemon confirmation and preserves advanced issues''', (tester) async {
      await bddSetUp(tester);
      await iDragPlanningStoryTo(tester, 'ST291', 'Review');
      await iSavePlanningMoves(tester);
      await planningStoryHasNoPendingMove(tester, 'ST291');
      await thePlanningStoryIsIn(tester, 'ST291', 'Implementing');
      await iExpandPlanningStoryIssues(tester, 'ST291');
      await advancedPlanningIssuesKeepTheirState(tester);
    });
    testWidgets('''Save several stories atomically''', (tester) async {
      await bddSetUp(tester);
      await iDragPlanningStoryTo(tester, 'ST291', 'Review');
      await iDragPlanningStoryTo(tester, 'ST293', 'Review');
      await iSavePlanningMoves(tester);
      await planningStoryHasNoPendingMove(tester, 'ST291');
      await planningStoryHasNoPendingMove(tester, 'ST293');
      await thePlanningStoryIsIn(tester, 'ST291', 'Implementing');
      await thePlanningStoryIsIn(tester, 'ST293', 'Review');
    });
    testWidgets('''A stale revision rereads and keeps the remaining intent usable''', (tester) async {
      await bddSetUp(tester);
      await iDragPlanningStoryTo(tester, 'ST291', 'Review');
      await thePlanningRevisionChangesOnTheMachine(tester);
      await iSavePlanningMoves(tester);
      await thePlanningMoveNoticeSays(tester, 'Planning changed');
      await planningStoryHasAPendingMove(tester, 'ST291');
      await planningSaveIsUsable(tester);
      await iSavePlanningMoves(tester);
      await planningStoryHasNoPendingMove(tester, 'ST291');
      await thePlanningStoryIsIn(tester, 'ST291', 'Implementing');
    });
    testWidgets('''A refusal keeps the pending move and the daemon words''', (tester) async {
      await bddSetUp(tester);
      await thePlanningMachineRefusesMovesWith(tester, 'Work is still running');
      await iDragPlanningStoryTo(tester, 'ST291', 'Review');
      await iSavePlanningMoves(tester);
      await planningStoryShowsRefusal(tester, 'ST291', 'Work is still running');
      await planningStoryHasAPendingMove(tester, 'ST291');
      await thePlanningStoryIsIn(tester, 'ST291', 'Backlog');
      await planningStoryIsNotMarkedMoved(tester, 'ST291');
      await planningSaveIsUsable(tester);
      await iReloadPlanningMoves(tester);
      await planningStoryShowsRefusal(tester, 'ST291', 'Work is still running');
      await thePlanningStoryIsIn(tester, 'ST291', 'Backlog');
      await planningStoryIsNotMarkedMoved(tester, 'ST291');
    });
    testWidgets('''A working state requests a start and moves nothing''', (tester) async {
      await bddSetUp(tester);
      await iDragPlanningStoryTo(tester, 'ST291', 'Implementing');
      await planningStartWasRequestedForIn(tester, 'ST291', 'Implementing');
      await noPlanningMoveErrorIsShown(tester);
      await planningStoryHasNoPendingMove(tester, 'ST291');
      await thePlanningStoryIsIn(tester, 'ST291', 'Backlog');
    });
    testWidgets('''A closed destination accepts a pending drop''', (tester) async {
      await bddSetUp(tester);
      await iShowClosedPlanningStates(tester);
      await iDragPlanningStoryTo(tester, 'ST291', 'Finished');
      await planningStoryHasAPendingMove(tester, 'ST291');
      await thePlanningStoryIsIn(tester, 'ST291', 'Finished');
    });
    testWidgets('''Leaving Planning asks first and can be canceled''', (tester) async {
      await bddSetUp(tester);
      await iDragPlanningStoryTo(tester, 'ST291', 'Review');
      await iTryToLeavePlanningMoves(tester);
      await planningAsksBeforeLeaving(tester);
      await iKeepEditingPlanningMoves(tester);
      await thePlanningPageIsShown(tester);
      await planningStoryHasAPendingMove(tester, 'ST291');
    });
    testWidgets('''Closing the window asks first and can be canceled''', (tester) async {
      await bddSetUp(tester);
      await iDragPlanningStoryTo(tester, 'ST291', 'Review');
      await iAskToCloseIt(tester);
      await planningAsksBeforeLeaving(tester);
      await iKeepEditingPlanningMoves(tester);
      await thePlanningWindowCloseIsCanceled(tester);
      await planningStoryHasAPendingMove(tester, 'ST291');
    });
    testWidgets('''Confirmed navigation keeps moves pending for the return''', (tester) async {
      await bddSetUp(tester);
      await iDragPlanningStoryTo(tester, 'ST291', 'Review');
      await iTryToLeavePlanningMoves(tester);
      await iLeavePlanningMovesPending(tester);
      await theWorkPageIsShown(tester);
      await iOpenThePlanningBoard(tester);
      await planningStoryHasAPendingMove(tester, 'ST291');
      await thePlanningStoryIsIn(tester, 'ST291', 'Review');
    });
    testWidgets('''Hover names the destination and Undo all restores every card''', (tester) async {
      await bddSetUp(tester);
      await iHoldPlanningStoryOver(tester, 'ST291', 'Review');
      await thePlanningDropHintNames(tester, 'Review');
      await iDropThePlanningStory(tester);
      await iDragPlanningStoryTo(tester, 'ST292', 'Review');
      await planningStoryIsMarkedMoved(tester, 'ST291');
      await planningStoryIsMarkedMoved(tester, 'ST292');
      await iUndoAllPlanningMoves(tester);
      await planningStoryHasNoPendingMove(tester, 'ST291');
      await planningStoryHasNoPendingMove(tester, 'ST292');
      await thePlanningStoryIsIn(tester, 'ST291', 'Backlog');
      await thePlanningStoryIsIn(tester, 'ST292', 'Backlog');
    });
    testWidgets('''Undo a refusal and save the other card''', (tester) async {
      await bddSetUp(tester);
      await thePlanningMachineRefusesStoryWith(tester, 'ST291', 'Work is still running');
      await iDragPlanningStoryTo(tester, 'ST291', 'Review');
      await iDragPlanningStoryTo(tester, 'ST293', 'Review');
      await iSavePlanningMoves(tester);
      await planningStoryShowsRefusal(tester, 'ST291', 'Work is still running');
      await planningStoryShowsRefusal(tester, 'ST293', 'Work is still running');
      await planningStoryIsNotMarkedMoved(tester, 'ST293');
      await iUndoPlanningStory(tester, 'ST291');
      await planningSaveIsUsable(tester);
      await iSavePlanningMoves(tester);
      await noPlanningMoveErrorIsShown(tester);
      await planningStoryHasNoPendingMove(tester, 'ST293');
      await thePlanningStoryIsIn(tester, 'ST293', 'Review');
      await thePlanningStoryIsIn(tester, 'ST291', 'Backlog');
    });
    testWidgets('''A folded refused card keeps its own reason''', (tester) async {
      await bddSetUp(tester);
      await thePlanningMachineRefusesMovesWith(tester, 'Work is still running');
      await iDragPlanningStoryTo(tester, 'ST291', 'Review');
      await iSavePlanningMoves(tester);
      await iFoldThePlanningPhase(tester, 'Backlog');
      await planningStoryShowsRefusal(tester, 'ST291', 'Work is still running');
      await planningStoryIsNotMarkedMoved(tester, 'ST291');
    });
    testWidgets('''Window close keeps one existing planning question''', (tester) async {
      await bddSetUp(tester);
      await iDragPlanningStoryTo(tester, 'ST291', 'Review');
      await iTryToLeavePlanningMoves(tester);
      await iAskToCloseIt(tester);
      await planningAsksBeforeLeaving(tester);
      await iKeepEditingPlanningMoves(tester);
      await thePlanningPageIsShown(tester);
      await planningStoryHasAPendingMove(tester, 'ST291');
    });
    testWidgets('''A refusal naming one story returns the whole batch''', (tester) async {
      await bddSetUp(tester);
      await thePlanningSaveRefusesForStoryWith(tester, 'NoSuchStory', 'ST291', 'The story is unknown');
      await iDragPlanningStoryTo(tester, 'ST291', 'Review');
      await iDragPlanningStoryTo(tester, 'ST292', 'Review');
      await iSavePlanningMoves(tester);
      await planningStoryShowsRefusal(tester, 'ST291', 'The story is unknown');
      await planningStoryShowsRefusal(tester, 'ST292', 'The story is unknown');
      await planningStoryIsNotMarkedMoved(tester, 'ST291');
      await planningStoryIsNotMarkedMoved(tester, 'ST292');
      await thePlanningStoryIsIn(tester, 'ST291', 'Backlog');
      await thePlanningStoryIsIn(tester, 'ST292', 'Backlog');
    });
    testWidgets('''An unnamed refusal returns every submitted card to its reported column''', (tester) async {
      await bddSetUp(tester);
      await thePlanningMachineRefusesMovesWith(tester, 'The board cannot be written');
      await iDragPlanningStoryTo(tester, 'ST291', 'Review');
      await iDragPlanningStoryTo(tester, 'ST292', 'Review');
      await iSavePlanningMoves(tester);
      await planningStoryShowsRefusal(tester, 'ST291', 'The board cannot be written');
      await planningStoryShowsRefusal(tester, 'ST292', 'The board cannot be written');
      await planningStoryIsNotMarkedMoved(tester, 'ST291');
      await planningStoryIsNotMarkedMoved(tester, 'ST292');
      await thePlanningStoryIsIn(tester, 'ST291', 'Backlog');
      await thePlanningStoryIsIn(tester, 'ST292', 'Backlog');
    });
    testWidgets('''A new save clears the previous problems before showing its new refusal''', (tester) async {
      await bddSetUp(tester);
      await thePlanningMachineRefusesStoryWith(tester, 'ST291', 'Work is still running');
      await iDragPlanningStoryTo(tester, 'ST291', 'Review');
      await iDragPlanningStoryTo(tester, 'ST292', 'Review');
      await iSavePlanningMoves(tester);
      await planningStoryShowsRefusal(tester, 'ST291', 'Work is still running');
      await thePlanningSaveRefusesForStoryWith(tester, 'AnotherRefusal', 'ST292', 'This story cannot move');
      await iSavePlanningMoves(tester);
      await planningStoryShowsRefusal(tester, 'ST291', 'This story cannot move');
      await planningStoryNoLongerShowsRefusal(tester, 'ST291', 'Work is still running');
      await planningStoryShowsRefusal(tester, 'ST292', 'This story cannot move');
      await planningStoryNoLongerShowsRefusal(tester, 'ST292', 'Work is still running');
      await planningStoryIsNotMarkedMoved(tester, 'ST292');
      await thePlanningStoryIsIn(tester, 'ST292', 'Backlog');
    });
    testWidgets('''Undo all clears the stale save feedback''', (tester) async {
      await bddSetUp(tester);
      await iDragPlanningStoryTo(tester, 'ST291', 'Review');
      await thePlanningRevisionChangesOnTheMachine(tester);
      await iSavePlanningMoves(tester);
      await thePlanningMoveNoticeSays(tester, 'Planning changed');
      await iUndoAllPlanningMoves(tester);
      await noPlanningMoveErrorIsShown(tester);
      await noPlanningMoveNoticeIsShown(tester);
      await planningStoryHasNoPendingMove(tester, 'ST291');
      await thePlanningStoryIsIn(tester, 'ST291', 'Backlog');
    });
    testWidgets('''A working card does not offer its own state as a destination''', (tester) async {
      await bddSetUp(tester);
      await iSearchPlanningFor(tester, 'ST27');
      await iHoldPlanningStoryOver(tester, 'ST27', 'Implementing');
      await noPlanningDropHintNames(tester, 'Implementing');
      await iDropThePlanningStory(tester);
      await noPlanningStartIsRequested(tester);
      await planningStoryHasNoPendingMove(tester, 'ST27');
      await thePlanningStoryIsIn(tester, 'ST27', 'Implementing');
    });
  });
}
