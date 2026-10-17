// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_the_work.dart';
import './step/i_start_watching_another_machine.dart';
import './step/i_choose.dart';
import './step/i_say_it_is_at.dart';
import './step/its_socket_there_is.dart';
import './step/i_try_the_connection.dart';
import './step/the_trial_says.dart';
import './step/the_forward_raised_for_the_trial_was_taken_down.dart';
import './step/raising_a_forward_will_fail_with.dart';
import './step/nothing_answers_on_that_machine.dart';
import './step/the_account_logs_in_as_uid.dart';
import './step/the_machine_was_asked_who_logs_in_as.dart';
import './step/its_socket_there_reads.dart';
import './step/nothing_was_raised_for_the_trial.dart';
import './step/starting_porelo_there_is_not_offered.dart';
import './step/starting_porelo_there_is_offered.dart';
import './step/i_turn_the_offer_down.dart';
import './step/nothing_was_started_on_that_machine.dart';
import './step/the_question_is_asked_in_its_own_dialog.dart';
import './step/the_question_does_not_show_the_command_it_runs.dart';
import './step/i_ask_to_see_the_command_it_runs.dart';
import './step/the_question_shows.dart';
import './step/i_start_porelo_there.dart';
import './step/the_machine_was_asked_to_start.dart';
import './step/starting_porelo_will_fail_with.dart';
import './step/the_start_says.dart';
import './step/i_cancel_the_dialog.dart';
import './step/i_go_to_what_needs_a_person.dart';
import './step/a_failed_operation_waits_saying.dart';
import './step/the_forwarded_socket_is.dart';
import './step/the_machine_serves_nothing_this_build_knows.dart';
import './step/the_trial_says_nothing.dart';

void main() {
  group('''Trying a machine from the dialog, before it is watched''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await iGoToTheWork(tester);
      await iStartWatchingAnotherMachine(tester);
    }

    testWidgets('''a machine that answers says what it is, and nothing is left running''', (tester) async {
      await bddSetUp(tester);
      await iChoose(tester, 'Raise the forward for me');
      await iSayItIsAt(tester, 'user@build.example.test');
      await itsSocketThereIs(tester, '/run/user/1001/porelo/porelod.sock');
      await iTryTheConnection(tester);
      await theTrialSays(tester, 'Reached Porelo 0.1.0-mock');
      await theForwardRaisedForTheTrialWasTakenDown(tester);
    });
    testWidgets('''a forward ssh cannot raise says what ssh said''', (tester) async {
      await bddSetUp(tester);
      await raisingAForwardWillFailWith(tester, 'Host key verification failed.');
      await iChoose(tester, 'Raise the forward for me');
      await iSayItIsAt(tester, 'user@build.example.test');
      await itsSocketThereIs(tester, '/run/user/1001/porelo/porelod.sock');
      await iTryTheConnection(tester);
      await theTrialSays(tester, 'Host key verification failed.');
      await theForwardRaisedForTheTrialWasTakenDown(tester);
    });
    testWidgets('''a forward to a socket nobody serves points at the far end''', (tester) async {
      await bddSetUp(tester);
      await nothingAnswersOnThatMachine(tester);
      await iChoose(tester, 'Raise the forward for me');
      await iSayItIsAt(tester, 'user@build.example.test');
      await itsSocketThereIs(tester, '/run/user/1001/porelo/porelod.sock');
      await iTryTheConnection(tester);
      await theTrialSays(tester, 'nothing answers at /run/user/1001/porelo/porelod.sock on that machine');
      await theForwardRaisedForTheTrialWasTakenDown(tester);
    });
    testWidgets('''a socket left empty is asked of the machine, shown filled in, and tried''', (tester) async {
      await bddSetUp(tester);
      await theAccountLogsInAsUid(tester, 1001);
      await iChoose(tester, 'Raise the forward for me');
      await iSayItIsAt(tester, 'user@build.example.test');
      await iTryTheConnection(tester);
      await theMachineWasAskedWhoLogsInAs(tester, 'user@build.example.test');
      await itsSocketThereReads(tester, '/run/user/1001/porelo/porelod.sock');
      await theTrialSays(tester, 'Reached Porelo 0.1.0-mock');
    });
    testWidgets('''a socket left empty on a machine that cannot be asked says how to go on, and tries nothing''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await iChoose(tester, 'Raise the forward for me');
      await iSayItIsAt(tester, 'user@build.example.test');
      await iTryTheConnection(tester);
      await theTrialSays(tester, 'Could not log in to user@build.example.test to ask where Porelo is for you there');
      await theTrialSays(tester, 'or type its socket');
      await nothingWasRaisedForTheTrial(tester);
    });
    testWidgets('''a socket in another user's runtime directory is named as that, with the path meant''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await nothingAnswersOnThatMachine(tester);
      await theAccountLogsInAsUid(tester, 1000);
      await iChoose(tester, 'Raise the forward for me');
      await iSayItIsAt(tester, 'user@build.example.test');
      await itsSocketThereIs(tester, '/run/user/1001/porelo/porelod.sock');
      await iTryTheConnection(tester);
      await theTrialSays(tester, 'runtime directory (uid 1001)');
      await theTrialSays(tester, 'Did you mean /run/user/1000/porelo/porelod.sock');
      await startingPoreloThereIsNotOffered(tester);
    });
    testWidgets('''a socket under the login's own uid still says that nothing answers''', (tester) async {
      await bddSetUp(tester);
      await nothingAnswersOnThatMachine(tester);
      await theAccountLogsInAsUid(tester, 1001);
      await iChoose(tester, 'Raise the forward for me');
      await iSayItIsAt(tester, 'user@build.example.test');
      await itsSocketThereIs(tester, '/run/user/1001/porelo/porelod.sock');
      await iTryTheConnection(tester);
      await theTrialSays(tester, 'nothing answers at /run/user/1001/porelo/porelod.sock on that machine');
      await startingPoreloThereIsOffered(tester);
      await iTurnTheOfferDown(tester);
      await nothingWasStartedOnThatMachine(tester);
    });
    testWidgets('''a machine nobody serves is offered a start, and nothing runs until it is asked for''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await nothingAnswersOnThatMachine(tester);
      await iChoose(tester, 'Raise the forward for me');
      await iSayItIsAt(tester, 'user@build.example.test');
      await itsSocketThereIs(tester, '/run/user/1001/porelo/porelod.sock');
      await iTryTheConnection(tester);
      await startingPoreloThereIsOffered(tester);
      await theQuestionIsAskedInItsOwnDialog(tester);
      await theQuestionDoesNotShowTheCommandItRuns(tester);
      await iAskToSeeTheCommandItRuns(tester);
      await theQuestionShows(tester, 'setsid porelod');
      await nothingWasStartedOnThatMachine(tester);
      await iStartPoreloThere(tester);
      await theMachineWasAskedToStart(tester, 'setsid porelod');
      await theTrialSays(tester, 'Reached Porelo');
    });
    testWidgets('''the offer is turned down and nothing is run''', (tester) async {
      await bddSetUp(tester);
      await nothingAnswersOnThatMachine(tester);
      await iChoose(tester, 'Raise the forward for me');
      await iSayItIsAt(tester, 'user@build.example.test');
      await itsSocketThereIs(tester, '/run/user/1001/porelo/porelod.sock');
      await iTryTheConnection(tester);
      await iTurnTheOfferDown(tester);
      await startingPoreloThereIsNotOffered(tester);
      await nothingWasStartedOnThatMachine(tester);
    });
    testWidgets('''a start that failed says what came back''', (tester) async {
      await bddSetUp(tester);
      await nothingAnswersOnThatMachine(tester);
      await startingPoreloWillFailWith(tester, 'no porelod is installed there');
      await iChoose(tester, 'Raise the forward for me');
      await iSayItIsAt(tester, 'user@build.example.test');
      await itsSocketThereIs(tester, '/run/user/1001/porelo/porelod.sock');
      await iTryTheConnection(tester);
      await iStartPoreloThere(tester);
      await theStartSays(tester, 'no porelod is installed there');
    });
    testWidgets('''a start that failed in the dialog waits under what needs a person once it is closed''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await nothingAnswersOnThatMachine(tester);
      await startingPoreloWillFailWith(tester, 'no porelod is installed there');
      await iChoose(tester, 'Raise the forward for me');
      await iSayItIsAt(tester, 'user@build.example.test');
      await itsSocketThereIs(tester, '/run/user/1001/porelo/porelod.sock');
      await iTryTheConnection(tester);
      await iStartPoreloThere(tester);
      await iCancelTheDialog(tester);
      await iGoToWhatNeedsAPerson(tester);
      await aFailedOperationWaitsSaying(tester, 'no porelod is installed there');
    });
    testWidgets('''a forward ssh could not raise is never offered a start''', (tester) async {
      await bddSetUp(tester);
      await raisingAForwardWillFailWith(tester, 'Host key verification failed.');
      await iChoose(tester, 'Raise the forward for me');
      await iSayItIsAt(tester, 'user@build.example.test');
      await itsSocketThereIs(tester, '/run/user/1001/porelo/porelod.sock');
      await iTryTheConnection(tester);
      await startingPoreloThereIsNotOffered(tester);
    });
    testWidgets('''a socket somebody else forwarded names no host to log into''', (tester) async {
      await bddSetUp(tester);
      await nothingAnswersOnThatMachine(tester);
      await iChoose(tester, 'Its socket is already forwarded');
      await theForwardedSocketIs(tester, '/tmp/porelod-remote.sock');
      await iTryTheConnection(tester);
      await startingPoreloThereIsNotOffered(tester);
    });
    testWidgets('''a machine that speaks something else says so''', (tester) async {
      await bddSetUp(tester);
      await theMachineServesNothingThisBuildKnows(tester);
      await iChoose(tester, 'Its socket is already forwarded');
      await theForwardedSocketIs(tester, '/tmp/porelod-remote.sock');
      await iTryTheConnection(tester);
      await theTrialSays(tester, 'serves nothing this build understands');
    });
    testWidgets('''a socket already forwarded is tried without raising anything''', (tester) async {
      await bddSetUp(tester);
      await iChoose(tester, 'Its socket is already forwarded');
      await theForwardedSocketIs(tester, '/tmp/porelod-remote.sock');
      await iTryTheConnection(tester);
      await theTrialSays(tester, 'Reached Porelo');
      await nothingWasRaisedForTheTrial(tester);
    });
    testWidgets('''changing where it is takes the old answer away''', (tester) async {
      await bddSetUp(tester);
      await iChoose(tester, 'Raise the forward for me');
      await iSayItIsAt(tester, 'user@build.example.test');
      await itsSocketThereIs(tester, '/run/user/1001/porelo/porelod.sock');
      await iTryTheConnection(tester);
      await iSayItIsAt(tester, 'user@other.example.test');
      await theTrialSaysNothing(tester);
    });
  });
}
