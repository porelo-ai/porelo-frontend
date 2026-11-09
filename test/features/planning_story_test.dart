// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_planning_details.dart';
import './step/the_app_is_running.dart';
import './step/i_open_the_planning_board.dart';
import './step/i_open_planning_story.dart';
import './step/planning_details_contain.dart';
import './step/the_planning_issue_table_is_shown.dart';
import './step/the_planning_breadcrumb_is.dart';
import './step/planning_is_selected_in_the_rail.dart';
import './step/i_open_planning_issue.dart';
import './step/the_last_planning_findings_put_blocking_first.dart';
import './step/i_unfold_planning_story.dart';
import './step/i_search_planning_for.dart';
import './step/i_filter_planning_to_high_and_above.dart';
import './step/i_fold_the_planning_phase.dart';
import './step/i_scroll_the_planning_board.dart';
import './step/i_remember_the_planning_board_position.dart';
import './step/i_press_planning_breadcrumb.dart';
import './step/the_planning_board_position_is_retained.dart';
import './step/i_press_planning_back.dart';
import './step/the_planning_board_is_visible.dart';
import './step/i_open_the_planning_web_link.dart';
import './step/the_planning_browser_opened.dart';
import './step/the_machine_gives_the_planning_issue_link.dart';
import './step/the_planning_web_link_is_absent.dart';
import './step/the_machine_updates_the_planning_details.dart';
import './step/planning_detail_reads_are_refused.dart';
import './step/the_planning_detail_error_is.dart';
import './step/the_planning_message_appears_once.dart';
import './step/the_planning_story_issue_list_is_unreported.dart';
import './step/planning_details_do_not_contain.dart';
import './step/the_planning_watch_fails.dart';
import './step/the_planning_story_read_is_delayed.dart';
import './step/the_delayed_planning_story_arrives.dart';
import './step/planning_has_no_asynchronous_error.dart';
import './step/i_use_a_narrow_planning_pane.dart';
import './step/the_machine_reports_incomplete_planning_finding_numbers.dart';
import './step/the_machine_reports_malformed_planning_findings.dart';
import './step/another_machine_offers_the_same_project_planning.dart';
import './step/the_planning_board_contains.dart';
import './step/the_machine_reports_malformed_planning_blockers.dart';
import './step/the_planning_section_contains.dart';
import './step/the_machine_lists_planning_issue_under_story.dart';
import './step/i_open_the_planning_owner_story.dart';
import './step/the_planning_part_is_refused.dart';
import './step/the_planning_story_has_known_work.dart';
import './step/the_planning_task_is_available.dart';
import './step/i_open_the_planning_task.dart';
import './step/the_planning_work_opened_is.dart';
import './step/the_planning_story_has_unknown_work.dart';
import './step/the_planning_task_is_disabled_with.dart';
import './step/i_remove_the_planning_provider.dart';
import './step/the_unavailable_planning_source_is_shown.dart';
import './step/the_planning_issue_has_partial_sections.dart';
import './step/the_planning_replacement_part_is_refused.dart';
import './step/i_retry_planning.dart';
import './step/the_machine_reports_an_empty_planning_finding_file.dart';
import './step/the_planning_issue_row_says.dart';
import './step/the_planning_issue_row_does_not_say.dart';
import './step/the_planning_story_reports_mode.dart';
import './step/i_move_planning_issue_to.dart';
import './step/the_planning_issue_still_reports.dart';
import './step/the_planning_issue_has_pending_state.dart';
import './step/there_are_pending_planning_moves.dart';
import './step/the_planning_move_reply_is_held.dart';
import './step/i_save_the_planning_moves.dart';
import './step/planning_changes_are_being_saved.dart';
import './step/the_planning_move_reply_arrives.dart';
import './step/the_planning_issue_reports.dart';
import './step/planning_issue_changes_are_saved.dart';
import './step/i_undo_the_planning_moves.dart';
import './step/no_planning_moves_are_pending.dart';
import './step/the_planning_move_revision_becomes_stale.dart';
import './step/the_planning_move_is_refused_with.dart';
import './step/the_planning_move_for_says.dart';
import './step/the_planning_move_for_has_no_refusal.dart';

void main() {
  group('''Open stories and issues from planning''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithPlanningDetails(tester);
      await theAppIsRunning(tester);
      await iOpenThePlanningBoard(tester);
    }

    testWidgets('''A card opens its story''', (tester) async {
      await bddSetUp(tester);
      await iOpenPlanningStory(tester, 'ST291');
      await planningDetailsContain(tester, '# Story source');
      await planningDetailsContain(tester, '0 of 15 in Review or Finished');
      await thePlanningIssueTableIsShown(tester);
      await thePlanningBreadcrumbIs(tester, 'Planning,ST291');
      await planningIsSelectedInTheRail(tester);
    });
    testWidgets('''An issue shows its last reading and sub-agents''', (tester) async {
      await bddSetUp(tester);
      await iOpenPlanningStory(tester, 'ST291');
      await iOpenPlanningIssue(tester, 'B541');
      await thePlanningBreadcrumbIs(tester, 'Planning,ST291,B541');
      await planningIsSelectedInTheRail(tester);
      await planningDetailsContain(tester, 'Only confirmed work is published');
      await planningDetailsContain(tester, 'Read the final changes');
      await theLastPlanningFindingsPutBlockingFirst(tester);
    });
    testWidgets('''An unfolded card opens an issue directly''', (tester) async {
      await bddSetUp(tester);
      await iUnfoldPlanningStory(tester, 'ST291');
      await iOpenPlanningIssue(tester, 'B541');
      await thePlanningBreadcrumbIs(tester, 'Planning,ST291,B541');
      await planningDetailsContain(tester, 'The host tool reads the organization');
    });
    testWidgets('''Breadcrumbs retain the board position''', (tester) async {
      await bddSetUp(tester);
      await iSearchPlanningFor(tester, 'ST');
      await iFilterPlanningToHighAndAbove(tester);
      await iFoldThePlanningPhase(tester, 'Analysis');
      await iScrollThePlanningBoard(tester);
      await iRememberThePlanningBoardPosition(tester);
      await iOpenPlanningStory(tester, 'ST291');
      await iOpenPlanningIssue(tester, 'B541');
      await iPressPlanningBreadcrumb(tester, 1);
      await thePlanningBreadcrumbIs(tester, 'Planning,ST291');
      await iPressPlanningBreadcrumb(tester, 0);
      await thePlanningBoardPositionIsRetained(tester);
    });
    testWidgets('''Escape follows the planning breadcrumb''', (tester) async {
      await bddSetUp(tester);
      await iOpenPlanningStory(tester, 'ST291');
      await iOpenPlanningIssue(tester, 'B541');
      await iPressPlanningBack(tester);
      await thePlanningBreadcrumbIs(tester, 'Planning,ST291');
      await iPressPlanningBack(tester);
      await thePlanningBoardIsVisible(tester);
    });
    testWidgets('''Browser links use the exact addresses''', (tester) async {
      await bddSetUp(tester);
      await iOpenPlanningStory(tester, 'ST291');
      await iOpenThePlanningWebLink(tester, 'Open story');
      await thePlanningBrowserOpened(tester, 'https://example.org/stories/ST291');
      await iOpenPlanningIssue(tester, 'B541');
      await iOpenThePlanningWebLink(tester, 'Open issue');
      await thePlanningBrowserOpened(tester, 'https://example.org/issues/B541');
    });
    testWidgets('''An absent issue link is not offered''', (tester) async {
      await bddSetUp(tester);
      await theMachineGivesThePlanningIssueLink(tester, '');
      await iUnfoldPlanningStory(tester, 'ST291');
      await iOpenPlanningIssue(tester, 'B541');
      await thePlanningWebLinkIsAbsent(tester, 'Open issue');
    });
    testWidgets('''Outline: Only valid HTTPS links are offered (http://example.org/issue)''', (tester) async {
      await bddSetUp(tester);
      await theMachineGivesThePlanningIssueLink(tester, 'http://example.org/issue');
      await iUnfoldPlanningStory(tester, 'ST291');
      await iOpenPlanningIssue(tester, 'B541');
      await thePlanningWebLinkIsAbsent(tester, 'Open issue');
    });
    testWidgets('''Outline: Only valid HTTPS links are offered (https:issue)''', (tester) async {
      await bddSetUp(tester);
      await theMachineGivesThePlanningIssueLink(tester, 'https:issue');
      await iUnfoldPlanningStory(tester, 'ST291');
      await iOpenPlanningIssue(tester, 'B541');
      await thePlanningWebLinkIsAbsent(tester, 'Open issue');
    });
    testWidgets('''Outline: Only valid HTTPS links are offered (file:///tmp/issue)''', (tester) async {
      await bddSetUp(tester);
      await theMachineGivesThePlanningIssueLink(tester, 'file:///tmp/issue');
      await iUnfoldPlanningStory(tester, 'ST291');
      await iOpenPlanningIssue(tester, 'B541');
      await thePlanningWebLinkIsAbsent(tester, 'Open issue');
    });
    testWidgets('''The watch refreshes the opened issue and its story''', (tester) async {
      await bddSetUp(tester);
      await iUnfoldPlanningStory(tester, 'ST291');
      await iOpenPlanningIssue(tester, 'B541');
      await theMachineUpdatesThePlanningDetails(tester);
      await planningDetailsContain(tester, 'Updated issue title');
      await iPressPlanningBreadcrumb(tester, 1);
      await planningDetailsContain(tester, 'Updated story title');
      await planningDetailsContain(tester, '1 of 15 in Review or Finished');
    });
    testWidgets('''A detail refusal keeps the daemon words''', (tester) async {
      await bddSetUp(tester);
      await planningDetailReadsAreRefused(tester);
      await iOpenPlanningStory(tester, 'ST291');
      await thePlanningDetailErrorIs(tester, 'Story: The story store is locked for repair');
      await thePlanningMessageAppearsOnce(tester, 'Story: The story store is locked for repair');
    });
    testWidgets('''An issue refusal keeps the daemon words''', (tester) async {
      await bddSetUp(tester);
      await planningDetailReadsAreRefused(tester);
      await iUnfoldPlanningStory(tester, 'ST291');
      await iOpenPlanningIssue(tester, 'B541');
      await thePlanningDetailErrorIs(tester, 'Issue: The story store is locked for repair');
      await thePlanningMessageAppearsOnce(tester, 'Issue: The story store is locked for repair');
    });
    testWidgets('''An unreported issue list stays unknown''', (tester) async {
      await bddSetUp(tester);
      await thePlanningStoryIssueListIsUnreported(tester);
      await iOpenPlanningStory(tester, 'ST291');
      await planningDetailsContain(tester, 'Issues not reported');
      await planningDetailsDoNotContain(tester, 'No issues yet.');
    });
    testWidgets('''An empty story shows its empty list''', (tester) async {
      await bddSetUp(tester);
      await iOpenPlanningStory(tester, 'ST294');
      await planningDetailsContain(tester, 'No issues yet.');
      await planningDetailsDoNotContain(tester, '0 of 0 in Review or Finished');
    });
    testWidgets('''A watch failure marks the detail stale''', (tester) async {
      await bddSetUp(tester);
      await iOpenPlanningStory(tester, 'ST291');
      await thePlanningWatchFails(tester);
      await planningDetailsContain(tester, 'The last answer may be out of date');
      await planningDetailsContain(tester, 'store cannot be read');
    });
    testWidgets('''A late story reply cannot reopen details''', (tester) async {
      await bddSetUp(tester);
      await thePlanningStoryReadIsDelayed(tester);
      await iOpenPlanningStory(tester, 'ST291');
      await thePlanningMessageAppearsOnce(tester, 'Waiting for the machine’s planning answer.');
      await iPressPlanningBreadcrumb(tester, 0);
      await theDelayedPlanningStoryArrives(tester);
      await thePlanningBoardIsVisible(tester);
      await planningHasNoAsynchronousError(tester);
    });
    testWidgets('''Details remain reachable in a narrow window''', (tester) async {
      await bddSetUp(tester);
      await iUnfoldPlanningStory(tester, 'ST291');
      await iOpenPlanningIssue(tester, 'B541');
      await iUseANarrowPlanningPane(tester);
      await thePlanningBreadcrumbIs(tester, 'Planning,ST291,B541');
      await planningHasNoAsynchronousError(tester);
      await iPressPlanningBreadcrumb(tester, 1);
      await thePlanningBreadcrumbIs(tester, 'Planning,ST291');
    });
    testWidgets('''Incomplete finding numbers remain readable''', (tester) async {
      await bddSetUp(tester);
      await theMachineReportsIncompletePlanningFindingNumbers(tester);
      await iUnfoldPlanningStory(tester, 'ST291');
      await iOpenPlanningIssue(tester, 'B541');
      await planningDetailsContain(tester, 'First unnumbered finding');
      await planningDetailsContain(tester, 'Second unnumbered finding');
      await planningDetailsContain(tester, 'Repeated number first');
      await planningDetailsContain(tester, 'Repeated number second');
      await planningHasNoAsynchronousError(tester);
    });
    testWidgets('''A malformed findings report stays unknown''', (tester) async {
      await bddSetUp(tester);
      await theMachineReportsMalformedPlanningFindings(tester);
      await iUnfoldPlanningStory(tester, 'ST291');
      await iOpenPlanningIssue(tester, 'B541');
      await planningDetailsContain(tester, 'Findings not reported completely');
      await planningDetailsDoNotContain(tester, 'No findings in the last reading.');
    });
    testWidgets('''Provider fallback retains the board and detail owner''', (tester) async {
      await bddSetUp(tester);
      await anotherMachineOffersTheSameProjectPlanning(tester);
      await iSearchPlanningFor(tester, 'ST');
      await iFilterPlanningToHighAndAbove(tester);
      await iFoldThePlanningPhase(tester, 'Analysis');
      await iScrollThePlanningBoard(tester);
      await iRememberThePlanningBoardPosition(tester);
      await iOpenPlanningStory(tester, 'ST291');
      await thePlanningWatchFails(tester);
      await planningDetailsContain(tester, '# Story source');
      await planningDetailsDoNotContain(tester, 'Story supplied by another machine');
      await iPressPlanningBreadcrumb(tester, 0);
      await thePlanningBoardPositionIsRetained(tester);
      await thePlanningBoardContains(tester, 'Story supplied by another machine');
    });
    testWidgets('''Malformed blockers remain unknown''', (tester) async {
      await bddSetUp(tester);
      await theMachineReportsMalformedPlanningBlockers(tester);
      await iUnfoldPlanningStory(tester, 'ST291');
      await iOpenPlanningIssue(tester, 'B541');
      await thePlanningSectionContains(tester, 'Blocked by', 'Not reported');
    });
    testWidgets('''The reported issue owner opens its own story''', (tester) async {
      await bddSetUp(tester);
      await iUnfoldPlanningStory(tester, 'ST291');
      await iOpenPlanningIssue(tester, 'B541');
      await theMachineListsPlanningIssueUnderStory(tester, 'B541', 'ST294');
      await thePlanningSectionContains(tester, 'Story', 'ST294');
      await iOpenThePlanningOwnerStory(tester);
      await thePlanningBreadcrumbIs(tester, 'Planning,ST294');
    });
    testWidgets('''A failed parent leaves the issue and its link readable''', (tester) async {
      await bddSetUp(tester);
      await thePlanningPartIsRefused(tester, 'Story');
      await iUnfoldPlanningStory(tester, 'ST291');
      await iOpenPlanningIssue(tester, 'B541');
      await thePlanningDetailErrorIs(tester, 'Story: This part is locked for repair');
      await planningDetailsContain(tester, 'Only confirmed work is published');
      await iOpenThePlanningWebLink(tester, 'Open issue');
      await thePlanningBrowserOpened(tester, 'https://example.org/issues/B541');
    });
    testWidgets('''A failed issue list leaves the story and its link readable''', (tester) async {
      await bddSetUp(tester);
      await thePlanningPartIsRefused(tester, 'Issue list');
      await iOpenPlanningStory(tester, 'ST291');
      await thePlanningDetailErrorIs(tester, 'Issue list: This part is locked for repair');
      await planningDetailsContain(tester, '# Story source');
      await planningDetailsDoNotContain(tester, 'Issues not reported');
      await iOpenThePlanningWebLink(tester, 'Open story');
      await thePlanningBrowserOpened(tester, 'https://example.org/stories/ST291');
    });
    testWidgets('''A story work link opens its task''', (tester) async {
      await bddSetUp(tester);
      await thePlanningStoryHasKnownWork(tester);
      await iOpenPlanningStory(tester, 'ST291');
      await thePlanningTaskIsAvailable(tester, 'porelo-checkout-shell');
      await iOpenThePlanningTask(tester, 'porelo-checkout-shell');
      await thePlanningWorkOpenedIs(tester, 'porelo-checkout-shell');
    });
    testWidgets('''An issue builder link opens its task''', (tester) async {
      await bddSetUp(tester);
      await thePlanningStoryHasKnownWork(tester);
      await iUnfoldPlanningStory(tester, 'ST291');
      await iOpenPlanningIssue(tester, 'B541');
      await thePlanningTaskIsAvailable(tester, 'porelo-checkout-shell');
      await iOpenThePlanningTask(tester, 'porelo-checkout-shell');
      await thePlanningWorkOpenedIs(tester, 'porelo-checkout-shell');
    });
    testWidgets('''Unknown story work explains why it cannot open''', (tester) async {
      await bddSetUp(tester);
      await thePlanningStoryHasUnknownWork(tester);
      await iOpenPlanningStory(tester, 'ST291');
      await thePlanningTaskIsDisabledWith(tester, 'missing-task', 'does not know task missing-task');
    });
    testWidgets('''Unknown issue work explains why it cannot open''', (tester) async {
      await bddSetUp(tester);
      await thePlanningStoryHasUnknownWork(tester);
      await iUnfoldPlanningStory(tester, 'ST291');
      await iOpenPlanningIssue(tester, 'B541');
      await thePlanningTaskIsDisabledWith(tester, 'missing-task', 'does not know task missing-task');
    });
    testWidgets('''Removing a provider closes its detail safely''', (tester) async {
      await bddSetUp(tester);
      await anotherMachineOffersTheSameProjectPlanning(tester);
      await iOpenPlanningStory(tester, 'ST291');
      await iRemoveThePlanningProvider(tester);
      await theUnavailablePlanningSourceIsShown(tester);
      await planningHasNoAsynchronousError(tester);
    });
    testWidgets('''Partial acceptance and sub-agent reports are labeled incomplete''', (tester) async {
      await bddSetUp(tester);
      await thePlanningIssueHasPartialSections(tester);
      await iUnfoldPlanningStory(tester, 'ST291');
      await iOpenPlanningIssue(tester, 'B541');
      await planningDetailsContain(tester, 'Acceptance criteria not reported completely');
      await planningDetailsContain(tester, 'Sub-agents not reported completely');
      await planningDetailsContain(tester, 'Visible reader');
    });
    testWidgets('''A failed story leaves its issue table readable''', (tester) async {
      await bddSetUp(tester);
      await thePlanningPartIsRefused(tester, 'Story');
      await iOpenPlanningStory(tester, 'ST291');
      await thePlanningDetailErrorIs(tester, 'Story: This part is locked for repair');
      await thePlanningIssueTableIsShown(tester);
    });
    testWidgets('''A failed story reload retains the last details''', (tester) async {
      await bddSetUp(tester);
      await iOpenPlanningStory(tester, 'ST291');
      await thePlanningReplacementPartIsRefused(tester, 'Story');
      await planningDetailsContain(tester, '# Story source');
      await thePlanningIssueTableIsShown(tester);
      await thePlanningDetailErrorIs(tester, 'Story: This part is locked for repair');
      await thePlanningMessageAppearsOnce(tester, 'Story: This part is locked for repair');
    });
    testWidgets('''A failed issue list reload retains the last table''', (tester) async {
      await bddSetUp(tester);
      await iOpenPlanningStory(tester, 'ST291');
      await thePlanningReplacementPartIsRefused(tester, 'Issue list');
      await thePlanningIssueTableIsShown(tester);
      await planningDetailsContain(tester, '# Story source');
      await thePlanningDetailErrorIs(tester, 'Issue list: This part is locked for repair');
    });
    testWidgets('''A failed issue reload retains the last issue''', (tester) async {
      await bddSetUp(tester);
      await iUnfoldPlanningStory(tester, 'ST291');
      await iOpenPlanningIssue(tester, 'B541');
      await thePlanningReplacementPartIsRefused(tester, 'Issue');
      await planningDetailsContain(tester, 'Only confirmed work is published');
      await thePlanningDetailErrorIs(tester, 'Issue: This part is locked for repair');
      await iOpenThePlanningWebLink(tester, 'Open issue');
      await thePlanningBrowserOpened(tester, 'https://example.org/issues/B541');
    });
    testWidgets('''The detail watch can be retried''', (tester) async {
      await bddSetUp(tester);
      await iOpenPlanningStory(tester, 'ST291');
      await thePlanningWatchFails(tester);
      await iRetryPlanning(tester);
      await planningDetailsDoNotContain(tester, 'The last answer may be out of date');
      await planningDetailsContain(tester, '# Story source');
    });
    testWidgets('''A finding with an empty file shows only its line''', (tester) async {
      await bddSetUp(tester);
      await theMachineReportsAnEmptyPlanningFindingFile(tester);
      await iUnfoldPlanningStory(tester, 'ST291');
      await iOpenPlanningIssue(tester, 'B541');
      await planningDetailsContain(tester, 'line 42');
      await planningDetailsDoNotContain(tester, ' · line 42');
    });
    testWidgets('''The board marks malformed blockers unknown''', (tester) async {
      await bddSetUp(tester);
      await theMachineReportsMalformedPlanningBlockers(tester);
      await iUnfoldPlanningStory(tester, 'ST291');
      await thePlanningIssueRowSays(tester, 'B541', 'Blockers not reported');
      await thePlanningIssueRowDoesNotSay(tester, 'B541', 'Blocked by ');
    });
    testWidgets('''Outline: Work modes use their display names (UNATTENDED, unattended)''', (tester) async {
      await bddSetUp(tester);
      await thePlanningStoryReportsMode(tester, 'UNATTENDED');
      await iOpenPlanningStory(tester, 'ST291');
      await planningDetailsContain(tester, 'Mode: unattended');
      await planningDetailsDoNotContain(tester, 'Coordinator:');
    });
    testWidgets('''Outline: Work modes use their display names (AGENT, shell with you)''', (tester) async {
      await bddSetUp(tester);
      await thePlanningStoryReportsMode(tester, 'AGENT');
      await iOpenPlanningStory(tester, 'ST291');
      await planningDetailsContain(tester, 'Mode: shell with you');
      await planningDetailsDoNotContain(tester, 'Coordinator:');
    });
    testWidgets('''Outline: Work modes use their display names (FUTURE, FUTURE)''', (tester) async {
      await bddSetUp(tester);
      await thePlanningStoryReportsMode(tester, 'FUTURE');
      await iOpenPlanningStory(tester, 'ST291');
      await planningDetailsContain(tester, 'Mode: FUTURE');
      await planningDetailsDoNotContain(tester, 'Coordinator:');
    });
    testWidgets('''An issue moved alone and saved''', (tester) async {
      await bddSetUp(tester);
      await iOpenPlanningStory(tester, 'ST291');
      await iMovePlanningIssueTo(tester, 'B541', 'Review');
      await thePlanningIssueStillReports(tester, 'B541', 'Implementing');
      await thePlanningIssueHasPendingState(tester, 'B541', 'Review');
      await thePlanningIssueStillReports(tester, 'B540', 'Implementing');
      await thereArePendingPlanningMoves(tester, 1);
      await thePlanningMoveReplyIsHeld(tester);
      await iSaveThePlanningMoves(tester);
      await planningChangesAreBeingSaved(tester);
      await thePlanningIssueStillReports(tester, 'B541', 'Implementing');
      await thePlanningMoveReplyArrives(tester);
      await thePlanningIssueReports(tester, 'B541', 'Review');
      await thePlanningIssueReports(tester, 'B540', 'Implementing');
      await planningIssueChangesAreSaved(tester);
    });
    testWidgets('''Pending issue moves can be undone''', (tester) async {
      await bddSetUp(tester);
      await iOpenPlanningStory(tester, 'ST291');
      await iMovePlanningIssueTo(tester, 'B541', 'Review');
      await iUndoThePlanningMoves(tester);
      await thePlanningIssueReports(tester, 'B541', 'Implementing');
      await noPlanningMovesArePending(tester);
    });
    testWidgets('''A stale revision rereads and retains applicable issue moves''', (tester) async {
      await bddSetUp(tester);
      await iOpenPlanningStory(tester, 'ST291');
      await iMovePlanningIssueTo(tester, 'B540', 'Review');
      await iMovePlanningIssueTo(tester, 'B541', 'Review');
      await thePlanningMoveRevisionBecomesStale(tester);
      await iSaveThePlanningMoves(tester);
      await planningDetailsContain(tester, 'Planning changed. Review the pending moves and save again.');
      await thePlanningIssueReports(tester, 'B540', 'Review');
      await thePlanningIssueReports(tester, 'B541', 'Implementing');
      await thePlanningIssueHasPendingState(tester, 'B541', 'Review');
      await thereArePendingPlanningMoves(tester, 1);
      await iSaveThePlanningMoves(tester);
      await thePlanningIssueReports(tester, 'B541', 'Review');
      await planningIssueChangesAreSaved(tester);
    });
    testWidgets(
      '''Outline: Daemon refusals identify the affected pending issue (MoveNotAllowed, Policy refused this move)''',
      (tester) async {
        await bddSetUp(tester);
        await thePlanningMoveIsRefusedWith(tester, 'MoveNotAllowed');
        await iOpenPlanningStory(tester, 'ST291');
        await iMovePlanningIssueTo(tester, 'B540', 'Review');
        await iMovePlanningIssueTo(tester, 'B541', 'Review');
        await iSaveThePlanningMoves(tester);
        await thePlanningMoveForSays(tester, 'B541', 'Policy refused this move');
        await thePlanningMoveForHasNoRefusal(tester, 'B540');
        await thePlanningIssueReports(tester, 'B540', 'Implementing');
        await thePlanningIssueReports(tester, 'B541', 'Implementing');
        await thereArePendingPlanningMoves(tester, 2);
      },
    );
    testWidgets(
      '''Outline: Daemon refusals identify the affected pending issue (StateNotAllowed, Policy refused this move)''',
      (tester) async {
        await bddSetUp(tester);
        await thePlanningMoveIsRefusedWith(tester, 'StateNotAllowed');
        await iOpenPlanningStory(tester, 'ST291');
        await iMovePlanningIssueTo(tester, 'B540', 'Review');
        await iMovePlanningIssueTo(tester, 'B541', 'Review');
        await iSaveThePlanningMoves(tester);
        await thePlanningMoveForSays(tester, 'B541', 'Policy refused this move');
        await thePlanningMoveForHasNoRefusal(tester, 'B540');
        await thePlanningIssueReports(tester, 'B540', 'Implementing');
        await thePlanningIssueReports(tester, 'B541', 'Implementing');
        await thereArePendingPlanningMoves(tester, 2);
      },
    );
    testWidgets(
      '''Outline: Daemon refusals identify the affected pending issue (EnteredOnlyByWork, entered only by work)''',
      (tester) async {
        await bddSetUp(tester);
        await thePlanningMoveIsRefusedWith(tester, 'EnteredOnlyByWork');
        await iOpenPlanningStory(tester, 'ST291');
        await iMovePlanningIssueTo(tester, 'B540', 'Review');
        await iMovePlanningIssueTo(tester, 'B541', 'Review');
        await iSaveThePlanningMoves(tester);
        await thePlanningMoveForSays(tester, 'B541', 'entered only by work');
        await thePlanningMoveForHasNoRefusal(tester, 'B540');
        await thePlanningIssueReports(tester, 'B540', 'Implementing');
        await thePlanningIssueReports(tester, 'B541', 'Implementing');
        await thereArePendingPlanningMoves(tester, 2);
      },
    );
  });
}
