// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_the_work.dart';
import './step/i_select_the_project.dart';
import './step/i_choose_the_command.dart';
import './step/i_close_what_is_open.dart';
import './step/the_work_is_listed.dart';
import './step/the_operation_is_still_running.dart';
import './step/the_operation_prints.dart';
import './step/the_operation_shows.dart';
import './step/is_nowhere_on_the_frame.dart';
import './step/i_show_what_this_session_has_run.dart';
import './step/i_open_the_last_operation.dart';
import './step/the_operation_finishes.dart';
import './step/the_record_shows.dart';
import './step/the_operation_fails.dart';
import './step/the_record_marks_it_as_failed.dart';
import './step/the_operation_runs_out_of_time.dart';
import './step/the_run_is_refused_before_it_begins.dart';
import './step/i_go_to_what_needs_a_person.dart';
import './step/a_failed_operation_waits_saying.dart';
import './step/the_count_of_what_needs_a_person_is.dart';
import './step/i_open_the_failed_operation_from_what_needs_a_person.dart';
import './step/no_failed_operation_waits.dart';
import './step/the_app_is_restarted.dart';
import './step/the_file_of_what_was_run_was_opened.dart';
import './step/the_project_has_the_repositories.dart';
import './step/i_show_what_the_repository_would_open.dart';
import './step/the_operation_is_open.dart';
import './step/the_launch_was_a_dry_run_in_the_repository.dart';
import './step/the_launch_was_a_dry_run_in_no_repository.dart';

void main() {
  group('''Running long operations without blocking the frame''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await iGoToTheWork(tester);
      await iSelectTheProject(tester, 'checkout');
    }

    testWidgets('''the frame stays usable while a long operation runs''',
        (tester) async {
      await bddSetUp(tester);
      await iChooseTheCommand(
          tester, 'Show what this project would open, creating nothing');
      await iCloseWhatIsOpen(tester);
      await iSelectTheProject(tester, 'checkout');
      await theWorkIsListed(tester, 'porelo-checkout-shell');
      await theOperationIsStillRunning(tester);
    });
    testWidgets('''output goes to the operation and disturbs nothing else''',
        (tester) async {
      await bddSetUp(tester);
      await iChooseTheCommand(
          tester, 'Show what this project would open, creating nothing');
      await theOperationPrints(tester, 'Building the image');
      await theOperationShows(tester, 'Building the image');
      await iCloseWhatIsOpen(tester);
      await isNowhereOnTheFrame(tester, 'Building the image');
    });
    testWidgets(
        '''an operation can be left and watched again without stopping it''',
        (tester) async {
      await bddSetUp(tester);
      await iChooseTheCommand(
          tester, 'Show what this project would open, creating nothing');
      await theOperationPrints(tester, 'step one');
      await iCloseWhatIsOpen(tester);
      await theOperationPrints(tester, 'step two');
      await iShowWhatThisSessionHasRun(tester);
      await iOpenTheLastOperation(tester);
      await theOperationShows(tester, 'step one');
      await theOperationShows(tester, 'step two');
      await theOperationIsStillRunning(tester);
    });
    testWidgets(
        '''everything this session ran is listed afterwards with its outcome''',
        (tester) async {
      await bddSetUp(tester);
      await iChooseTheCommand(
          tester, 'Show what this project would open, creating nothing');
      await theOperationFinishes(tester);
      await iCloseWhatIsOpen(tester);
      await iShowWhatThisSessionHasRun(tester);
      await theRecordShows(tester, 'would open');
      await theRecordShows(tester, 'Finished.');
    });
    testWidgets(
        '''failure is reported where success would have been, with the output that explains it''',
        (tester) async {
      await bddSetUp(tester);
      await iChooseTheCommand(
          tester, 'Show what this project would open, creating nothing');
      await theOperationPrints(tester, 'could not read project.yml');
      await theOperationFails(tester);
      await iCloseWhatIsOpen(tester);
      await iShowWhatThisSessionHasRun(tester);
      await theRecordShows(tester, 'exited with code 1');
      await theRecordMarksItAsFailed(tester);
      await iOpenTheLastOperation(tester);
      await theOperationShows(tester, 'could not read project.yml');
    });
    testWidgets(
        '''a run stopped by its own time limit is not read as a run that went wrong''',
        (tester) async {
      await bddSetUp(tester);
      await iChooseTheCommand(
          tester, 'Show what this project would open, creating nothing');
      await theOperationPrints(tester, 'agent: editing lib/money.dart');
      await theOperationRunsOutOfTime(tester);
      await iCloseWhatIsOpen(tester);
      await iShowWhatThisSessionHasRun(tester);
      await theRecordShows(tester, 'ran out of the time it was given');
      await iOpenTheLastOperation(tester);
      await theOperationShows(tester, 'agent: editing lib/money.dart');
    });
    testWidgets(
        '''a run refused before it began says nothing was created, not that it failed''',
        (tester) async {
      await bddSetUp(tester);
      await iChooseTheCommand(
          tester, 'Show what this project would open, creating nothing');
      await theRunIsRefusedBeforeItBegins(tester);
      await iCloseWhatIsOpen(tester);
      await iShowWhatThisSessionHasRun(tester);
      await theRecordShows(tester, 'Nothing ran, and nothing was created');
    });
    testWidgets(
        '''a failure nobody watched waits under what needs a person until it is opened''',
        (tester) async {
      await bddSetUp(tester);
      await iChooseTheCommand(
          tester, 'Show what this project would open, creating nothing');
      await theOperationPrints(tester, 'could not read project.yml');
      await iCloseWhatIsOpen(tester);
      await theOperationFails(tester);
      await iGoToWhatNeedsAPerson(tester);
      await aFailedOperationWaitsSaying(tester, 'would open');
      await theCountOfWhatNeedsAPersonIs(tester, '1 need you');
      await iOpenTheFailedOperationFromWhatNeedsAPerson(tester);
      await theOperationShows(tester, 'could not read project.yml');
      await iCloseWhatIsOpen(tester);
      await iGoToWhatNeedsAPerson(tester);
      await noFailedOperationWaits(tester);
      await theCountOfWhatNeedsAPersonIs(tester, 'nothing needs you');
    });
    testWidgets('''a failure watched as it happened does not wait''',
        (tester) async {
      await bddSetUp(tester);
      await iChooseTheCommand(
          tester, 'Show what this project would open, creating nothing');
      await theOperationFails(tester);
      await iCloseWhatIsOpen(tester);
      await iGoToWhatNeedsAPerson(tester);
      await noFailedOperationWaits(tester);
    });
    testWidgets('''an operation that finished never waits''', (tester) async {
      await bddSetUp(tester);
      await iChooseTheCommand(
          tester, 'Show what this project would open, creating nothing');
      await iCloseWhatIsOpen(tester);
      await theOperationFinishes(tester);
      await iGoToWhatNeedsAPerson(tester);
      await noFailedOperationWaits(tester);
    });
    testWidgets('''a failure opened from the session record no longer waits''',
        (tester) async {
      await bddSetUp(tester);
      await iChooseTheCommand(
          tester, 'Show what this project would open, creating nothing');
      await iCloseWhatIsOpen(tester);
      await theOperationFails(tester);
      await iShowWhatThisSessionHasRun(tester);
      await iOpenTheLastOperation(tester);
      await iCloseWhatIsOpen(tester);
      await iGoToWhatNeedsAPerson(tester);
      await noFailedOperationWaits(tester);
    });
    testWidgets(
        '''what was run is listed again after a restart, marked as earlier''',
        (tester) async {
      await bddSetUp(tester);
      await iChooseTheCommand(
          tester, 'Show what this project would open, creating nothing');
      await theOperationFinishes(tester);
      await iCloseWhatIsOpen(tester);
      await theAppIsRestarted(tester);
      await iShowWhatThisSessionHasRun(tester);
      await theRecordShows(tester, 'would open');
      await theRecordShows(tester, 'earlier');
    });
    testWidgets('''a failure nobody opened still waits after a restart''',
        (tester) async {
      await bddSetUp(tester);
      await iChooseTheCommand(
          tester, 'Show what this project would open, creating nothing');
      await iCloseWhatIsOpen(tester);
      await theOperationFails(tester);
      await theAppIsRestarted(tester);
      await iGoToWhatNeedsAPerson(tester);
      await aFailedOperationWaitsSaying(tester, 'would open');
    });
    testWidgets('''the record says where it is kept''', (tester) async {
      await bddSetUp(tester);
      await iShowWhatThisSessionHasRun(tester);
      await theRecordShows(tester, 'Kept for 30 days in');
    });
    testWidgets('''the file of what was run is opened from the finder''',
        (tester) async {
      await bddSetUp(tester);
      await iChooseTheCommand(
          tester, 'Open the file of everything that was run');
      await theFileOfWhatWasRunWasOpened(tester);
    });
    testWidgets(
        '''what one repository would open is shown on its own, creating nothing''',
        (tester) async {
      await bddSetUp(tester);
      await theProjectHasTheRepositories(
          tester, 'checkout', 'checkout, payments-api');
      await iShowWhatTheRepositoryWouldOpen(tester, 'payments-api');
      await theOperationIsOpen(tester);
      await theLaunchWasADryRunInTheRepository(tester, 'payments-api');
    });
    testWidgets('''what the project would open names no repository''',
        (tester) async {
      await bddSetUp(tester);
      await iChooseTheCommand(
          tester, 'Show what this project would open, creating nothing');
      await theLaunchWasADryRunInNoRepository(tester);
    });
  });
}
