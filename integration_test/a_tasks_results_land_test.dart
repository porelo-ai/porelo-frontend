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
import './step/each_issue_is_in_reading_for_a_reader.dart';
import './step/the_window_starts_the_offered_reader_task_and_it_ends.dart';
import './step/the_idea_a_task_brought_back_is_an_issue_in_idea.dart';
import './step/the_findings_file_lies_where_the_projects_setting_says.dart';
import './step/the_window_starts_the_offered_rework_task_and_it_ends.dart';
import './step/the_findings_are_worked_off_and_the_file_is_deleted.dart';
import './step/a_fresh_clone_shows_the_findings_commit_and_its_deletion.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('''A task's results land where the next step and others find them''', () {
    testWidgets('''a reading's findings are kept, worked off by a rework, and an idea becomes an issue''', (
      tester,
    ) async {
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
      await eachIssueIsInReadingForAReader(tester);
      await theWindowStartsTheOfferedReaderTaskAndItEnds(tester);
      await theIdeaATaskBroughtBackIsAnIssueInIdea(tester);
      await theFindingsFileLiesWhereTheProjectsSettingSays(tester);
      await theWindowStartsTheOfferedReworkTaskAndItEnds(tester);
      await theFindingsAreWorkedOffAndTheFileIsDeleted(tester);
      await aFreshCloneShowsTheFindingsCommitAndItsDeletion(tester);
    });
  });
}
