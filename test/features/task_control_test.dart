// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_the_work.dart';
import './step/i_select_the_project.dart';
import './step/i_select_the_work.dart';
import './step/removing_will_refuse_because_the_work_is_held.dart';
import './step/i_ask_to_remove_the_selected_work.dart';
import './step/i_confirm.dart';
import './step/what_is_held_is_shown.dart';
import './step/the_status_line_mentions.dart';
import './step/i_choose.dart';
import './step/the_work_is_listed.dart';
import './step/removing_will_refuse_because_commits_are_held.dart';
import './step/the_removal_asked_to_rescue_what_was_held.dart';
import './step/the_removal_asked_to_discard_what_was_held.dart';
import './step/nothing_more_was_asked_of_the_backend.dart';
import './step/the_stop_asked_for.dart';
import './step/the_removal_asked_for.dart';
import './step/the_work_is_no_longer_listed.dart';
import './step/the_work_was_never_stopped.dart';
import './step/the_work_has_stopped.dart';
import './step/removing_will_refuse_because_the_work_still_runs.dart';
import './step/i_stop_the_selected_work.dart';
import './step/the_work_was_not_removed.dart';
import './step/the_confirmation_says.dart';
import './step/i_open_the_actions_for.dart';
import './step/the_action_is_offered_as_unavailable.dart';
import './step/i_give_this_work_something_to_read_by.dart';
import './step/the_work_reads_as.dart';
import './step/its_name_is_still_shown_as.dart';
import './step/i_open_the_selection.dart';
import './step/it_says_its_name_is.dart';
import './step/this_work_already_reads_as.dart';
import './step/the_caption_sent_was_empty.dart';
import './step/i_ask_what_this_work_should_read_as.dart';
import './step/it_says.dart';
import './step/i_ask_to_recreate_the_selected_work.dart';
import './step/i_agree_to_recreate_it.dart';
import './step/the_launch_was_called.dart';
import './step/nothing_was_started.dart';
import './step/the_project_has_the_repositories.dart';
import './step/the_work_works_in_the_repository.dart';
import './step/the_launch_was_in_the_repository.dart';

void main() {
  group('''Stopping, removing, renaming and recreating work, and what it costs''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await iGoToTheWork(tester);
      await iSelectTheProject(tester, 'checkout');
      await iSelectTheWork(tester, 'porelo-checkout-shell');
    }

    testWidgets('''work holding commits that never reached the gate is refused, not removed''', (tester) async {
      await bddSetUp(tester);
      await removingWillRefuseBecauseTheWorkIsHeld(tester);
      await iAskToRemoveTheSelectedWork(tester);
      await iConfirm(tester);
      await whatIsHeldIsShown(tester);
      await theStatusLineMentions(tester, 'holds work that never reached the gate');
      await iChoose(tester, 'Leave it alone');
      await theWorkIsListed(tester, 'porelo-checkout-shell');
    });
    testWidgets('''a long list of what is held still leaves the choice within reach''', (tester) async {
      await bddSetUp(tester);
      await removingWillRefuseBecauseCommitsAreHeld(tester, 60);
      await iAskToRemoveTheSelectedWork(tester);
      await iConfirm(tester);
      await iChoose(tester, 'Leave it alone');
      await theWorkIsListed(tester, 'porelo-checkout-shell');
    });
    testWidgets('''what is held can be pushed to the mirror before it is removed''', (tester) async {
      await bddSetUp(tester);
      await removingWillRefuseBecauseTheWorkIsHeld(tester);
      await iAskToRemoveTheSelectedWork(tester);
      await iConfirm(tester);
      await iChoose(tester, 'Push what it holds to the mirror, then remove it');
      await theRemovalAskedToRescueWhatWasHeld(tester);
    });
    testWidgets('''what is held is discarded only when that is chosen in those words''', (tester) async {
      await bddSetUp(tester);
      await removingWillRefuseBecauseTheWorkIsHeld(tester);
      await iAskToRemoveTheSelectedWork(tester);
      await iConfirm(tester);
      await iChoose(tester, 'Discard what it holds and remove it');
      await theRemovalAskedToDiscardWhatWasHeld(tester);
    });
    testWidgets('''leaving a refusal alone touches nothing''', (tester) async {
      await bddSetUp(tester);
      await removingWillRefuseBecauseTheWorkIsHeld(tester);
      await iAskToRemoveTheSelectedWork(tester);
      await iConfirm(tester);
      await iChoose(tester, 'Leave it alone');
      await nothingMoreWasAskedOfTheBackend(tester);
      await theWorkIsListed(tester, 'porelo-checkout-shell');
      await theStatusLineMentions(tester, 'nothing was touched');
    });
    testWidgets('''running work is stopped before it is removed, and stops being listed''', (tester) async {
      await bddSetUp(tester);
      await iAskToRemoveTheSelectedWork(tester);
      await iConfirm(tester);
      await theStopAskedFor(tester, 'porelo-checkout-shell');
      await theRemovalAskedFor(tester, 'porelo-checkout-shell');
      await theStatusLineMentions(tester, 'was removed');
      await theStatusLineMentions(tester, '3 paths only it held went with it');
      await theWorkIsNoLongerListed(tester, 'porelo-checkout-shell');
    });
    testWidgets('''running work that holds commits is asked about before anything stops it''', (tester) async {
      await bddSetUp(tester);
      await removingWillRefuseBecauseTheWorkIsHeld(tester);
      await iAskToRemoveTheSelectedWork(tester);
      await iConfirm(tester);
      await whatIsHeldIsShown(tester);
      await theWorkWasNeverStopped(tester);
    });
    testWidgets('''a removal the machine says still runs is stopped, then removed''', (tester) async {
      await bddSetUp(tester);
      await theWorkHasStopped(tester, 'porelo-checkout-shell');
      await removingWillRefuseBecauseTheWorkStillRuns(tester);
      await iAskToRemoveTheSelectedWork(tester);
      await iConfirm(tester);
      await theStopAskedFor(tester, 'porelo-checkout-shell');
      await theRemovalAskedFor(tester, 'porelo-checkout-shell');
    });
    testWidgets('''stopping keeps the work, to be started again''', (tester) async {
      await bddSetUp(tester);
      await iStopTheSelectedWork(tester);
      await theStopAskedFor(tester, 'porelo-checkout-shell');
      await theWorkWasNotRemoved(tester);
      await theStatusLineMentions(tester, 'It is kept, workspace and all');
      await theWorkIsListed(tester, 'porelo-checkout-shell');
    });
    testWidgets('''the confirmation names what is destroyed along with the work''', (tester) async {
      await bddSetUp(tester);
      await iAskToRemoveTheSelectedWork(tester);
      await theConfirmationSays(tester, 'exists nowhere else');
    });
    testWidgets('''an action the state does not allow is offered as unavailable, not hidden''', (tester) async {
      await bddSetUp(tester);
      await iOpenTheActionsFor(tester, 'porelo-checkout-shell');
      await theActionIsOfferedAsUnavailable(tester, 'Start it again');
    });
    testWidgets('''an action with no method behind it says so rather than going missing''', (tester) async {
      await bddSetUp(tester);
      await iOpenTheActionsFor(tester, 'porelo-checkout-shell');
      await theActionIsOfferedAsUnavailable(tester, 'Rename it');
    });
    testWidgets('''work carries a caption a person can change, beside its identity''', (tester) async {
      await bddSetUp(tester);
      await iGiveThisWorkSomethingToReadBy(tester, 'schema migration, second attempt');
      await theWorkReadsAs(tester, 'schema migration, second attempt');
      await itsNameIsStillShownAs(tester, 'porelo-checkout-shell');
    });
    testWidgets('''the caption never becomes the identity''', (tester) async {
      await bddSetUp(tester);
      await iGiveThisWorkSomethingToReadBy(tester, 'schema migration');
      await iOpenTheSelection(tester);
      await itSaysItsNameIs(tester, 'porelo-checkout-shell');
    });
    testWidgets('''an empty caption takes it away rather than storing nothing''', (tester) async {
      await bddSetUp(tester);
      await thisWorkAlreadyReadsAs(tester, 'schema migration');
      await iGiveThisWorkSomethingToReadBy(tester, '');
      await theWorkReadsAs(tester, 'porelo-checkout-shell');
      await theCaptionSentWasEmpty(tester);
    });
    testWidgets('''the dialog says the name will not move''', (tester) async {
      await bddSetUp(tester);
      await iAskWhatThisWorkShouldReadAs(tester);
      await itSays(tester, 'Its name stays porelo-checkout-shell');
    });
    testWidgets('''recreating says why it exists, and what it costs''', (tester) async {
      await bddSetUp(tester);
      await iAskToRecreateTheSelectedWork(tester);
      await itSays(tester, 'picks up a newly built environment');
      await itSays(tester, 'goes with it and exists nowhere else');
    });
    testWidgets('''recreating takes it down and starts the same work again''', (tester) async {
      await bddSetUp(tester);
      await iAskToRecreateTheSelectedWork(tester);
      await iAgreeToRecreateIt(tester);
      await theRemovalAskedFor(tester, 'porelo-checkout-shell');
      await theLaunchWasCalled(tester, 'shell');
    });
    testWidgets('''work that holds unpushed commits stops the recreation, and says so''', (tester) async {
      await bddSetUp(tester);
      await removingWillRefuseBecauseTheWorkIsHeld(tester);
      await iAskToRecreateTheSelectedWork(tester);
      await iAgreeToRecreateIt(tester);
      await whatIsHeldIsShown(tester);
      await nothingWasStarted(tester);
    });
    testWidgets('''recreating starts the same work again in the repository it worked in''', (tester) async {
      await bddSetUp(tester);
      await theProjectHasTheRepositories(tester, 'checkout', 'checkout, payments-api');
      await theWorkWorksInTheRepository(tester, 'porelo-checkout-shell', 'payments-api');
      await iAskToRecreateTheSelectedWork(tester);
      await iAgreeToRecreateIt(tester);
      await theLaunchWasInTheRepository(tester, 'payments-api');
    });
  });
}
