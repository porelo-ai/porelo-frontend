// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_the_work.dart';
import './step/i_select_the_project.dart';
import './step/i_show_what_has_been_backed_up_here.dart';
import './step/it_says.dart';
import './step/nothing_has_been_backed_up_here.dart';
import './step/i_consider_removing_the_first_backup.dart';
import './step/no_backup_was_removed.dart';
import './step/i_keep_the_backup.dart';
import './step/i_remove_the_backup.dart';
import './step/the_bundle_is_already_gone.dart';
import './step/i_ask_the_upstream_how_far_behind_this_project_is.dart';
import './step/the_upstream_was_asked_about.dart';
import './step/the_status_line_mentions.dart';
import './step/the_upstream_cannot_be_measured_because.dart';
import './step/i_consider_restoring_the_first_backup.dart';
import './step/nothing_was_restored.dart';
import './step/restoring_would_destroy.dart';
import './step/i_restore_from_it.dart';
import './step/restoring_from_the_missing_backup_is_not_offered.dart';
import './step/the_project_has_the_repositories.dart';
import './step/the_repository_is_behind_with_waiting.dart';
import './step/the_repository_says.dart';
import './step/the_projects_own_repository_is_not_listed.dart';
import './step/i_sync_the_repository.dart';
import './step/the_upstream_was_asked_about_the_repository.dart';
import './step/i_show_the_backups_of_the_repository.dart';
import './step/the_backups_and_the_restore_were_about_the_repository.dart';
import './step/no_repository_was_named_for_the_backups_or_the_upstream.dart';
import './step/the_repository_limits_its_memory_to.dart';
import './step/the_menu_of_the_repository_says.dart';
import './step/the_menu_of_the_repository_does_not_say.dart';

void main() {
  group('''Backups of a mirror: listing, removing, restoring, and upstream''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await iGoToTheWork(tester);
      await iSelectTheProject(tester, 'checkout');
    }

    testWidgets('''what has been taken is listed with enough to tell two apart''', (tester) async {
      await bddSetUp(tester);
      await iShowWhatHasBeenBackedUpHere(tester);
      await itSays(tester, '/srv/checkout/backups/before-sync.bundle');
      await itSays(tester, '2 pushes when it was taken');
      await itSays(tester, '4.0 MB now');
    });
    testWidgets('''a bundle somebody moved is shown as missing, never dropped''', (tester) async {
      await bddSetUp(tester);
      await iShowWhatHasBeenBackedUpHere(tester);
      await itSays(tester, '/srv/checkout/backups/moved-away.bundle');
      await itSays(tester, 'the file is not there any more');
    });
    testWidgets('''a project with no record says so, without claiming no bundle exists''', (tester) async {
      await bddSetUp(tester);
      await nothingHasBeenBackedUpHere(tester);
      await iShowWhatHasBeenBackedUpHere(tester);
      await itSays(tester, 'Nothing is recorded for this project');
      await itSays(tester, 'not the same as no bundle existing');
    });
    testWidgets('''removing one says what it held before anything goes''', (tester) async {
      await bddSetUp(tester);
      await iShowWhatHasBeenBackedUpHere(tester);
      await iConsiderRemovingTheFirstBackup(tester);
      await itSays(tester, 'It held 2 pushes nobody had reviewed');
      await noBackupWasRemoved(tester);
    });
    testWidgets('''keeping it removes nothing''', (tester) async {
      await bddSetUp(tester);
      await iShowWhatHasBeenBackedUpHere(tester);
      await iConsiderRemovingTheFirstBackup(tester);
      await iKeepTheBackup(tester);
      await noBackupWasRemoved(tester);
    });
    testWidgets('''agreeing removes it, and says what it held''', (tester) async {
      await bddSetUp(tester);
      await iShowWhatHasBeenBackedUpHere(tester);
      await iConsiderRemovingTheFirstBackup(tester);
      await iRemoveTheBackup(tester);
      await itSays(tester, 'Gone: the bundle and the record of it');
    });
    testWidgets('''clearing the record of a bundle already gone is not called a loss''', (tester) async {
      await bddSetUp(tester);
      await theBundleIsAlreadyGone(tester);
      await iShowWhatHasBeenBackedUpHere(tester);
      await iConsiderRemovingTheFirstBackup(tester);
      await iRemoveTheBackup(tester);
      await itSays(tester, 'The record is cleared. The file was already gone');
    });
    testWidgets('''asking the upstream is one action and says what it found''', (tester) async {
      await bddSetUp(tester);
      await iAskTheUpstreamHowFarBehindThisProjectIs(tester);
      await theUpstreamWasAskedAbout(tester, 'checkout');
      await theStatusLineMentions(tester, '3 commits behind the upstream, as of now');
    });
    testWidgets('''a project with no upstream is not reported as up to date''', (tester) async {
      await bddSetUp(tester);
      await theUpstreamCannotBeMeasuredBecause(tester, 'NO_UPSTREAM');
      await iAskTheUpstreamHowFarBehindThisProjectIs(tester);
      await theStatusLineMentions(tester, 'no upstream, so there is nothing to be behind');
    });
    testWidgets('''restoring says what it would overwrite before it does anything''', (tester) async {
      await bddSetUp(tester);
      await iShowWhatHasBeenBackedUpHere(tester);
      await iConsiderRestoringTheFirstBackup(tester);
      await itSays(tester, 'This writes over the mirror');
      await nothingWasRestored(tester);
    });
    testWidgets('''work nobody has reviewed refuses the restore, and says what would go''', (tester) async {
      await bddSetUp(tester);
      await restoringWouldDestroy(tester, 'migrate');
      await iShowWhatHasBeenBackedUpHere(tester);
      await iConsiderRestoringTheFirstBackup(tester);
      await iRestoreFromIt(tester);
      await itSays(tester, 'Refused: 1 push nobody has reviewed would be destroyed');
      await itSays(tester, 'Nothing was written');
    });
    testWidgets('''forcing past the refusal says afterwards what it destroyed''', (tester) async {
      await bddSetUp(tester);
      await restoringWouldDestroy(tester, 'migrate');
      await iShowWhatHasBeenBackedUpHere(tester);
      await iConsiderRestoringTheFirstBackup(tester);
      await iRestoreFromIt(tester);
      await iRestoreFromIt(tester);
      await itSays(tester, '1 unreviewed push is gone: migrate');
    });
    testWidgets('''a bundle that is not there any more cannot be restored from''', (tester) async {
      await bddSetUp(tester);
      await iShowWhatHasBeenBackedUpHere(tester);
      await restoringFromTheMissingBackupIsNotOffered(tester);
    });
    testWidgets('''every repository says how far it has got, on a line of its own''', (tester) async {
      await bddSetUp(tester);
      await theProjectHasTheRepositories(tester, 'checkout', 'checkout, payments-api');
      await theRepositoryIsBehindWithWaiting(tester, 'payments-api', '4', '2');
      await theRepositorySays(tester, 'payments-api', '2 waiting at the gate · 4 behind');
      await theProjectsOwnRepositoryIsNotListed(tester, 'checkout');
    });
    testWidgets('''a repository's upstream is asked about on its own''', (tester) async {
      await bddSetUp(tester);
      await theProjectHasTheRepositories(tester, 'checkout', 'checkout, payments-api');
      await iSyncTheRepository(tester, 'payments-api');
      await theUpstreamWasAskedAboutTheRepository(tester, 'payments-api');
    });
    testWidgets('''a repository's backups are its own, and are restored into it''', (tester) async {
      await bddSetUp(tester);
      await theProjectHasTheRepositories(tester, 'checkout', 'checkout, payments-api');
      await iShowTheBackupsOfTheRepository(tester, 'payments-api');
      await itSays(tester, 'Backups of checkout · payments-api');
      await iConsiderRestoringTheFirstBackup(tester);
      await iRestoreFromIt(tester);
      await theBackupsAndTheRestoreWereAboutTheRepository(tester, 'payments-api');
    });
    testWidgets('''a machine that names no repositories is asked about none''', (tester) async {
      await bddSetUp(tester);
      await iShowWhatHasBeenBackedUpHere(tester);
      await iConsiderRestoringTheFirstBackup(tester);
      await iAskTheUpstreamHowFarBehindThisProjectIs(tester);
      await noRepositoryWasNamedForTheBackupsOrTheUpstream(tester);
    });
    testWidgets('''a repository's limits are shown, the keys it replaced marked as its own''', (tester) async {
      await bddSetUp(tester);
      await theProjectHasTheRepositories(tester, 'checkout', 'checkout, payments-api');
      await theRepositoryLimitsItsMemoryTo(tester, 'payments-api', '4g');
      await theMenuOfTheRepositorySays(tester, 'payments-api', 'memory 4g (its own)');
      await theMenuOfTheRepositorySays(tester, 'payments-api', 'processes 512');
      await theMenuOfTheRepositoryDoesNotSay(tester, 'payments-api', 'processes 512 (its own)');
    });
  });
}
