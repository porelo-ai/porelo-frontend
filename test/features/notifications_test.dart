// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_the_work.dart';
import './step/i_select_the_project.dart';
import './step/work_is_blocked_reaching.dart';
import './step/somebody_is_told.dart';
import './step/it_was_told_as_something_that_cannot_wait.dart';
import './step/i_watch_another_machine_called.dart';
import './step/work_elsewhere_is_blocked_reaching.dart';
import './step/somebody_was_told_exactly_time.dart';
import './step/i_choose_the_command.dart';
import './step/the_operation_finishes.dart';
import './step/the_operation_fails.dart';
import './step/i_close_what_is_open.dart';
import './step/somebody_acts_on_what_they_were_told.dart';
import './step/the_operation_is_open.dart';
import './step/i_stop_being_told_about_this_project.dart';
import './step/nobody_was_told_anything.dart';
import './step/the_project_is_marked_as_silent.dart';
import './step/work_in_is_blocked_reaching.dart';

void main() {
  group('''Telling somebody who is not looking at the window''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await iGoToTheWork(tester);
      await iSelectTheProject(tester, 'checkout');
    }

    testWidgets('''a waiting decision reaches somebody who is not looking at the window''', (tester) async {
      await bddSetUp(tester);
      await workIsBlockedReaching(tester, 'api.example.test:443');
      await somebodyIsTold(tester, 'is asking to reach api.example.test:443');
      await itWasToldAsSomethingThatCannotWait(tester);
    });
    testWidgets('''a question on a machine added later reaches somebody too''', (tester) async {
      await bddSetUp(tester);
      await iWatchAnotherMachineCalled(tester, 'elsewhere');
      await workElsewhereIsBlockedReaching(tester, 'api.example.test:443');
      await somebodyIsTold(tester, 'is asking to reach api.example.test:443');
    });
    testWidgets('''the same question is never raised twice''', (tester) async {
      await bddSetUp(tester);
      await workIsBlockedReaching(tester, 'api.example.test:443');
      await workIsBlockedReaching(tester, 'api.example.test:443');
      await somebodyWasToldExactlyTime(tester, '1');
    });
    testWidgets('''finishing is told apart from failing''', (tester) async {
      await bddSetUp(tester);
      await iChooseTheCommand(tester, 'Show what this project would open, creating nothing');
      await theOperationFinishes(tester);
      await somebodyIsTold(tester, 'That is done');
      await iChooseTheCommand(tester, 'Show what this project would open, creating nothing');
      await theOperationFails(tester);
      await somebodyIsTold(tester, 'That did not work');
    });
    testWidgets('''acting on it opens the work it came from''', (tester) async {
      await bddSetUp(tester);
      await iChooseTheCommand(tester, 'Show what this project would open, creating nothing');
      await theOperationFinishes(tester);
      await iCloseWhatIsOpen(tester);
      await somebodyActsOnWhatTheyWereTold(tester);
      await theOperationIsOpen(tester);
    });
    testWidgets('''a project that has been turned off says nothing''', (tester) async {
      await bddSetUp(tester);
      await iSelectTheProject(tester, 'checkout');
      await iStopBeingToldAboutThisProject(tester);
      await workIsBlockedReaching(tester, 'api.example.test:443');
      await nobodyWasToldAnything(tester);
    });
    testWidgets('''a project that is turned off says so where it is listed''', (tester) async {
      await bddSetUp(tester);
      await iSelectTheProject(tester, 'checkout');
      await iStopBeingToldAboutThisProject(tester);
      await theProjectIsMarkedAsSilent(tester, 'checkout');
    });
    testWidgets('''turning a project off does not silence the others''', (tester) async {
      await bddSetUp(tester);
      await iSelectTheProject(tester, 'checkout');
      await iStopBeingToldAboutThisProject(tester);
      await workInIsBlockedReaching(tester, 'billing', 'api.example.test:443');
      await somebodyIsTold(tester, 'is asking to reach api.example.test:443');
    });
  });
}
