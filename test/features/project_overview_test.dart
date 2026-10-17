// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_the_work.dart';
import './step/the_project_says.dart';
import './step/the_project_is_marked_as_not_prepared.dart';
import './step/the_project_is_not_marked_as_not_prepared.dart';
import './step/the_project_says_are_waiting_at_the_gate.dart';
import './step/the_project_is_listed.dart';
import './step/the_project_is_marked_as_unusable.dart';
import './step/work_is_started_elsewhere_in.dart';
import './step/i_select_the_project.dart';
import './step/nothing_was_asked_of_the_backend_about.dart';
import './step/the_last_check_for_failed_leaving_a_stale_count.dart';
import './step/the_project_does_not_say.dart';
import './step/the_project_is_marked_as_stale.dart';
import './step/the_project_is_not_marked_as_stale.dart';
import './step/the_project_records_nothing_about_its_image.dart';
import './step/the_app_is_restarted.dart';
import './step/the_project_is_removed_at_the_machine.dart';
import './step/i_refresh_every_machine.dart';
import './step/the_project_is_not_listed.dart';
import './step/i_choose_to_refresh_automatically.dart';
import './step/seconds_pass.dart';
import './step/refreshing_automatically_is_off.dart';

void main() {
  group('''What each project is, and how far behind it has fallen''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await iGoToTheWork(tester);
    }

    testWidgets('''a project says what it is and how much work it has''', (tester) async {
      await bddSetUp(tester);
      await theProjectSays(tester, 'checkout', '1 of 2 running · guarded');
    });
    testWidgets('''a project whose environment is not prepared is marked''', (tester) async {
      await bddSetUp(tester);
      await theProjectIsMarkedAsNotPrepared(tester, 'unrecorded');
      await theProjectIsNotMarkedAsNotPrepared(tester, 'checkout');
    });
    testWidgets('''falling behind says by how much, and when that was measured''', (tester) async {
      await bddSetUp(tester);
      await theProjectSays(tester, 'checkout', '3 behind, as of 20 minutes ago');
    });
    testWidgets('''never checked is not the same sentence as up to date''', (tester) async {
      await bddSetUp(tester);
      await theProjectSays(tester, 'unrecorded', 'Never checked against the upstream');
    });
    testWidgets('''a project that reaches nothing says that, rather than reporting zero''', (tester) async {
      await bddSetUp(tester);
      await theProjectSays(tester, 'billing', 'Not checked: this project reaches nothing');
    });
    testWidgets('''work waiting for review is said on the row''', (tester) async {
      await bddSetUp(tester);
      await theProjectSaysAreWaitingAtTheGate(tester, 'checkout', '2');
    });
    testWidgets('''a project nothing can act on is listed and marked, never left out''', (tester) async {
      await bddSetUp(tester);
      await theProjectIsListed(tester, 'unrecorded');
      await theProjectIsMarkedAsUnusable(tester, 'unrecorded');
    });
    testWidgets('''what changed elsewhere arrives without anybody asking for it''', (tester) async {
      await bddSetUp(tester);
      await workIsStartedElsewhereIn(tester, 'checkout');
      await theProjectSays(tester, 'checkout', '2 of 3 running · guarded');
    });
    testWidgets('''selecting a project changes nothing about it''', (tester) async {
      await bddSetUp(tester);
      await iSelectTheProject(tester, 'checkout');
      await nothingWasAskedOfTheBackendAbout(tester, 'checkout');
    });
    testWidgets('''a count left over from an older measurement is not drawn as one''', (tester) async {
      await bddSetUp(tester);
      await theLastCheckForFailedLeavingAStaleCount(tester, 'billing');
      await iGoToTheWork(tester);
      await theProjectSays(tester, 'billing', 'The last check did not work');
      await theProjectDoesNotSay(tester, 'billing', '7 behind');
    });
    testWidgets('''an environment built before the project file changed is marked''', (tester) async {
      await bddSetUp(tester);
      await theProjectIsMarkedAsStale(tester, 'billing');
      await theProjectIsNotMarkedAsStale(tester, 'checkout');
    });
    testWidgets('''an image that records nothing about itself is not called stale''', (tester) async {
      await bddSetUp(tester);
      await theProjectRecordsNothingAboutItsImage(tester, 'checkout');
      await theAppIsRestarted(tester);
      await iGoToTheWork(tester);
      await theProjectIsNotMarkedAsStale(tester, 'checkout');
    });
    testWidgets('''a project removed at the machine goes when every machine is asked again''', (tester) async {
      await bddSetUp(tester);
      await theProjectIsRemovedAtTheMachine(tester, 'unrecorded');
      await iRefreshEveryMachine(tester);
      await theProjectIsNotListed(tester, 'unrecorded');
    });
    testWidgets('''every machine is asked again on its own, as often as chosen''', (tester) async {
      await bddSetUp(tester);
      await theProjectIsRemovedAtTheMachine(tester, 'unrecorded');
      await iChooseToRefreshAutomatically(tester, 'every 30 seconds');
      await secondsPass(tester, 31);
      await theProjectIsNotListed(tester, 'unrecorded');
    });
    testWidgets('''asking again on its own can be turned off, and that survives a restart''', (tester) async {
      await bddSetUp(tester);
      await theProjectIsRemovedAtTheMachine(tester, 'unrecorded');
      await iChooseToRefreshAutomatically(tester, 'off');
      await secondsPass(tester, 120);
      await theProjectIsListed(tester, 'unrecorded');
      await theAppIsRestarted(tester);
      await refreshingAutomaticallyIsOff(tester);
    });
  });
}
