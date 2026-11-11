// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_planning.dart';
import './step/the_app_is_running.dart';
import './step/i_open_the_planning_board.dart';
import './step/story_work_is_prepared_with.dart';
import './step/i_open_story_work_for.dart';
import './step/story_work_proves.dart';
import './step/i_choose_story_work.dart';
import './step/i_resolve_the_story_reading_with.dart';
import './step/the_planning_watch_fails.dart';
import './step/i_open_story_work_in_a_narrow_host.dart';
import './step/i_drop_story_on_working_state.dart';
import './step/another_machine_offers_the_same_project_planning.dart';

void main() {
  group('''Start and decide story work from the planning board''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithPlanning(tester);
      await theAppIsRunning(tester);
      await iOpenThePlanningBoard(tester);
    }

    testWidgets('''The proposal limits modes and supplies tasks and rounds''', (tester) async {
      await bddSetUp(tester);
      await storyWorkIsPreparedWith(tester, 'only unattended');
      await iOpenStoryWorkFor(tester, 'ST291');
      await storyWorkProves(tester, 'proposal defaults and allowed modes');
    });
    testWidgets('''Cancel starts nothing''', (tester) async {
      await bddSetUp(tester);
      await iOpenStoryWorkFor(tester, 'ST291');
      await iChooseStoryWork(tester, 'cancel');
      await storyWorkProves(tester, 'nothing started');
    });
    testWidgets('''Dropping a builder requires a comment''', (tester) async {
      await bddSetUp(tester);
      await iOpenStoryWorkFor(tester, 'ST291');
      await iChooseStoryWork(tester, 'drop builder');
      await storyWorkProves(tester, 'start disabled');
      await iChooseStoryWork(tester, 'comment and start');
      await storyWorkProves(tester, 'running work visible');
    });
    testWidgets('''Changed participants and reading limits reach the daemon''', (tester) async {
      await bddSetUp(tester);
      await iOpenStoryWorkFor(tester, 'ST291');
      await iChooseStoryWork(tester, 'change builder and rounds');
      await iChooseStoryWork(tester, 'refold issue rounds');
      await storyWorkProves(tester, 'per issue rounds retained');
      await storyWorkProves(tester, 'start disabled');
      await iChooseStoryWork(tester, 'comment and start');
      await storyWorkProves(tester, 'running work visible');
    });
    testWidgets('''A refused start shows the daemon detail''', (tester) async {
      await bddSetUp(tester);
      await iOpenStoryWorkFor(tester, 'ST291');
      await storyWorkIsPreparedWith(tester, 'start refused');
      await iChooseStoryWork(tester, 'start');
      await storyWorkProves(tester, 'refusal and original board');
    });
    testWidgets('''A changed board invalidates the proposal''', (tester) async {
      await bddSetUp(tester);
      await iOpenStoryWorkFor(tester, 'ST291');
      await storyWorkIsPreparedWith(tester, 'new revision');
      await storyWorkProves(tester, 'start disabled');
    });
    testWidgets('''Stop leaves the story where it stands''', (tester) async {
      await bddSetUp(tester);
      await iOpenStoryWorkFor(tester, 'ST291');
      await iChooseStoryWork(tester, 'start');
      await iChooseStoryWork(tester, 'stop');
      await storyWorkProves(tester, 'stopped where it stands');
    });
    testWidgets('''Ended work appears in Needs you''', (tester) async {
      await bddSetUp(tester);
      await storyWorkIsPreparedWith(tester, 'ended blocked');
      await iChooseStoryWork(tester, 'needs you');
      await storyWorkProves(tester, 'ended reason visible');
    });
    testWidgets('''Review anyway sends the current reading decision''', (tester) async {
      await bddSetUp(tester);
      await storyWorkIsPreparedWith(tester, 'stopped reading');
      await iChooseStoryWork(tester, 'needs you');
      await storyWorkProves(tester, 'blocking findings first');
      await iResolveTheStoryReadingWith(tester, 'REVIEW_ANYWAY');
      await storyWorkProves(tester, 'reading removed from open attention');
    });
    testWidgets('''One more round waits for the board echo''', (tester) async {
      await bddSetUp(tester);
      await storyWorkIsPreparedWith(tester, 'stopped reading without echo');
      await iChooseStoryWork(tester, 'needs you');
      await iResolveTheStoryReadingWith(tester, 'ONE_MORE_ROUND');
      await storyWorkProves(tester, 'decision waits for echo');
    });
    testWidgets('''Rework requires text''', (tester) async {
      await bddSetUp(tester);
      await storyWorkIsPreparedWith(tester, 'stopped reading');
      await iChooseStoryWork(tester, 'needs you');
      await iResolveTheStoryReadingWith(tester, 'REWORK');
      await storyWorkProves(tester, 'rework text required');
      await iChooseStoryWork(tester, 'send rework text');
      await storyWorkProves(tester, 'rework resolved on screen');
    });
    testWidgets('''A reading refusal leaves the decision visible''', (tester) async {
      await bddSetUp(tester);
      await storyWorkIsPreparedWith(tester, 'stopped reading');
      await iChooseStoryWork(tester, 'needs you');
      await storyWorkIsPreparedWith(tester, 'reading refused');
      await iResolveTheStoryReadingWith(tester, 'REVIEW_ANYWAY');
      await storyWorkProves(tester, 'reading refusal visible');
    });
    testWidgets('''A stale reading stays visible with decisions disabled''', (tester) async {
      await bddSetUp(tester);
      await storyWorkIsPreparedWith(tester, 'stopped reading');
      await iChooseStoryWork(tester, 'needs you');
      await thePlanningWatchFails(tester);
      await storyWorkProves(tester, 'stale reading retained');
    });
    testWidgets('''Start is usable in a narrow window''', (tester) async {
      await bddSetUp(tester);
      await iOpenStoryWorkInANarrowHost(tester);
      await storyWorkProves(tester, 'narrow dialog usable');
    });
    testWidgets('''A main agent model can be changed''', (tester) async {
      await bddSetUp(tester);
      await iOpenStoryWorkFor(tester, 'ST291');
      await iChooseStoryWork(tester, 'change main agent');
      await iChooseStoryWork(tester, 'change main model');
      await storyWorkProves(tester, 'main model visible');
      await iChooseStoryWork(tester, 'start');
      await storyWorkProves(tester, 'started main model visible');
    });
    testWidgets('''With you opens the terminal of the task the window started''', (tester) async {
      await bddSetUp(tester);
      await iOpenStoryWorkFor(tester, 'ST291');
      await iChooseStoryWork(tester, 'with you');
      await iChooseStoryWork(tester, 'start');
      await storyWorkProves(tester, 'with you terminal');
    });
    testWidgets('''The end of a task the window started reaches the planner''', (tester) async {
      await bddSetUp(tester);
      await iOpenStoryWorkFor(tester, 'ST291');
      await iChooseStoryWork(tester, 'start');
      await storyWorkIsPreparedWith(tester, 'started main task ended');
      await iChooseStoryWork(tester, 'needs you');
      await storyWorkProves(tester, 'reported end visible');
    });
    testWidgets('''Dropping on a working state opens its proposal''', (tester) async {
      await bddSetUp(tester);
      await iDropStoryOnWorkingState(tester, 'ST291', 'In analysis');
      await storyWorkProves(tester, 'drop dialog visible');
    });
    testWidgets('''Selecting a machine reads its own proposal''', (tester) async {
      await bddSetUp(tester);
      await anotherMachineOffersTheSameProjectPlanning(tester);
      await storyWorkIsPreparedWith(tester, 'second machine proposal');
      await iOpenStoryWorkFor(tester, 'ST291');
      await iChooseStoryWork(tester, 'other machine');
      await storyWorkProves(tester, 'other machine proposal visible');
    });
    testWidgets('''An ended task shows the last answer''', (tester) async {
      await bddSetUp(tester);
      await storyWorkIsPreparedWith(tester, 'ended task answer');
      await iChooseStoryWork(tester, 'needs you');
      await iChooseStoryWork(tester, 'expand attention');
      await storyWorkProves(tester, 'ended task answer visible');
    });
    testWidgets('''Unknown work does not offer Start''', (tester) async {
      await bddSetUp(tester);
      await storyWorkIsPreparedWith(tester, 'unknown work');
      await iChooseStoryWork(tester, 'open story menu');
      await storyWorkProves(tester, 'start unavailable');
    });
    testWidgets('''Waiting stories without work can start''', (tester) async {
      await bddSetUp(tester);
      await storyWorkProves(tester, 'waiting card quiet');
      await iChooseStoryWork(tester, 'open story menu');
      await storyWorkProves(tester, 'start available');
    });
    testWidgets('''Closed stories without work can start''', (tester) async {
      await bddSetUp(tester);
      await storyWorkIsPreparedWith(tester, 'closed story');
      await iChooseStoryWork(tester, 'show closed cards');
      await storyWorkProves(tester, 'closed card quiet');
      await iChooseStoryWork(tester, 'open story menu');
      await storyWorkProves(tester, 'start available');
    });
    testWidgets('''A working story without work says the status is missing''', (tester) async {
      await bddSetUp(tester);
      await storyWorkIsPreparedWith(tester, 'working without work');
      await storyWorkProves(tester, 'working work missing');
      await iChooseStoryWork(tester, 'open story menu');
      await storyWorkProves(tester, 'start unavailable');
    });
    testWidgets('''Sub-agent Change begins with the proposal and requires a difference''', (tester) async {
      await bddSetUp(tester);
      await iOpenStoryWorkFor(tester, 'ST291');
      await iChooseStoryWork(tester, 'change builder');
      await storyWorkProves(tester, 'change proposal prefilled');
      await iChooseStoryWork(tester, 'comment');
      await storyWorkProves(tester, 'start disabled');
      await iChooseStoryWork(tester, 'change builder agent');
      await iChooseStoryWork(tester, 'start');
      await storyWorkProves(tester, 'running work visible');
    });
  });
}
