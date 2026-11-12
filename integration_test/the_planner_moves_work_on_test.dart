// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import './step/the_interface_is_running.dart';
import './step/i_open_the_planning_of_the_walk_project.dart';
import './step/the_planner_from_the_path_answers_for_the_project.dart';
import './step/i_discuss_an_idea_with_the_walk_agent_until_the_discussion_ends.dart';
import './step/porelo_on_the_machine_says_the_discussion_ran_and_ended.dart';
import './step/the_window_hands_the_idea_in.dart';
import './step/the_planner_holds_the_story_with_its_issues_in_idea.dart';
import './step/i_move_each_issue_of_the_story_to_backlog_one_state_at_a_time.dart';
import './step/each_issue_stands_in_backlog_on_the_board_and_in_its_file.dart';
import './step/i_ask_for_the_work_of_the_story_to_implementing_with_the_walk_agent.dart';
import './step/the_proposal_moved_nothing.dart';
import './step/i_order_the_work_and_start_its_builder_task.dart';
import './step/the_builder_task_runs_and_the_story_stands_in_implementing.dart';
import './step/the_builder_agent_works_until_its_task_ends.dart';
import './step/the_forge_holds_the_work_of_the_builder_agent.dart';
import './step/the_window_posts_the_end_of_the_builder_task.dart';
import './step/reading_is_set_and_its_reader_runs_with_no_dialog_shown.dart';
import './step/the_readers_end.dart';
import './step/the_first_issue_stands_in_review.dart';
import './step/the_second_stands_in_reworking_and_needs_you_lists_it.dart';
import './step/i_open_its_needsyou_entry.dart';
import './step/the_reworking_dialog_is_open_and_no_task_was_started.dart';
import './step/a_task_fails_on_a_key_its_provider_refuses.dart';
import './step/the_failed_tasks_card_stays_with_a_warning_and_a_needsyou_entry_to_its_result.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('''The planner moves work on from state to state by itself''', () {
    testWidgets('''work ends, is read, and moves on to Review or Reworking with no start asked for''', (tester) async {
      await theInterfaceIsRunning(tester);
      await iOpenThePlanningOfTheWalkProject(tester);
      await thePlannerFromThePathAnswersForTheProject(tester);
      await iDiscussAnIdeaWithTheWalkAgentUntilTheDiscussionEnds(tester);
      await poreloOnTheMachineSaysTheDiscussionRanAndEnded(tester);
      await theWindowHandsTheIdeaIn(tester);
      await thePlannerHoldsTheStoryWithItsIssuesInIdea(tester);
      await iMoveEachIssueOfTheStoryToBacklogOneStateAtATime(tester);
      await eachIssueStandsInBacklogOnTheBoardAndInItsFile(tester);
      await iAskForTheWorkOfTheStoryToImplementingWithTheWalkAgent(tester);
      await theProposalMovedNothing(tester);
      await iOrderTheWorkAndStartItsBuilderTask(tester);
      await theBuilderTaskRunsAndTheStoryStandsInImplementing(tester);
      await theBuilderAgentWorksUntilItsTaskEnds(tester);
      await theForgeHoldsTheWorkOfTheBuilderAgent(tester);
      await theWindowPostsTheEndOfTheBuilderTask(tester);
      await readingIsSetAndItsReaderRunsWithNoDialogShown(tester);
      await theReadersEnd(tester);
      await theFirstIssueStandsInReview(tester);
      await theSecondStandsInReworkingAndNeedsYouListsIt(tester);
      await iOpenItsNeedsyouEntry(tester);
      await theReworkingDialogIsOpenAndNoTaskWasStarted(tester);
      await aTaskFailsOnAKeyItsProviderRefuses(tester);
      await theFailedTasksCardStaysWithAWarningAndANeedsyouEntryToItsResult(tester);
    });
  });
}
