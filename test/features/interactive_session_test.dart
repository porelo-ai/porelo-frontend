// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_the_work.dart';
import './step/i_select_the_project.dart';
import './step/i_select_the_work.dart';
import './step/i_work_in_it_by_hand.dart';
import './step/the_session_runs.dart';
import './step/i_start_watching_another_machine.dart';
import './step/i_choose.dart';
import './step/i_say_it_is_called.dart';
import './step/i_say_it_is_at.dart';
import './step/its_socket_there_is.dart';
import './step/i_watch_it.dart';
import './step/i_switch_to_the_machine.dart';
import './step/the_session_prints.dart';
import './step/the_session_shows.dart';
import './step/i_type_into_the_session.dart';
import './step/the_session_was_sent.dart';
import './step/i_open_the_command_finder.dart';
import './step/the_command_is_offered_as_unavailable.dart';
import './step/the_work_is_dead.dart';
import './step/the_command_is_unavailable_because.dart';
import './step/the_session_is_on_screen.dart';
import './step/the_work_pane_is_not_shown.dart';
import './step/i_go_to_what_needs_a_person.dart';
import './step/the_session_is_not_on_screen.dart';
import './step/i_go_to_the_place.dart';
import './step/i_leave_the_session.dart';
import './step/the_work_is_still_selected.dart';
import './step/i_close_what_is_open.dart';
import './step/sessions_are_open.dart';
import './step/i_work_in_by_hand_from_its_tile.dart';
import './step/the_session_on_screen_is.dart';
import './step/the_first_session_was_left.dart';
import './step/the_work_was_never_stopped.dart';
import './step/only_one_terminal_was_ever_opened.dart';
import './step/it_says.dart';
import './step/the_session_ends_with.dart';
import './step/no_session_is_open.dart';
import './step/it_does_not_say.dart';
import './step/enough_time_passes_to_go_back.dart';

void main() {
  group('''Working inside a container by hand, locally or over ssh''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await iGoToTheWork(tester);
      await iSelectTheProject(tester, 'billing');
      await iSelectTheWork(tester, 'porelo-billing-shell');
    }

    testWidgets('''a session is one action from where the work is listed''', (tester) async {
      await bddSetUp(tester);
      await iWorkInItByHand(tester);
      await theSessionRuns(tester, 'porelo task attach porelo-billing-shell');
    });
    testWidgets('''a machine reached over ssh runs the same verb, through a terminal of its own''', (tester) async {
      await bddSetUp(tester);
      await iStartWatchingAnotherMachine(tester);
      await iChoose(tester, 'Raise the forward for me');
      await iSayItIsCalled(tester, 'the build machine');
      await iSayItIsAt(tester, 'user@build.example.test');
      await itsSocketThereIs(tester, '/run/user/1001/porelo/porelod.sock');
      await iWatchIt(tester);
      await iSwitchToTheMachine(tester, 'the build machine');
      await iSelectTheProject(tester, 'billing');
      await iSelectTheWork(tester, 'porelo-billing-shell');
      await iWorkInItByHand(tester);
      await theSessionRuns(tester, 'ssh -t user@build.example.test porelo task attach porelo-billing-shell');
    });
    testWidgets('''what the far end prints is what is on the screen''', (tester) async {
      await bddSetUp(tester);
      await iWorkInItByHand(tester);
      await theSessionPrints(tester, 'root@porelo-billing-shell:/work#');
      await theSessionShows(tester, 'root@porelo-billing-shell:/work#');
    });
    testWidgets('''what is typed reaches the far end''', (tester) async {
      await bddSetUp(tester);
      await iWorkInItByHand(tester);
      await iTypeIntoTheSession(tester, 'ls -l');
      await theSessionWasSent(tester, 'ls -l');
    });
    testWidgets('''an offline project may be worked in by hand, though it may not be widened''', (tester) async {
      await bddSetUp(tester);
      await iOpenTheCommandFinder(tester);
      await theCommandIsOfferedAsUnavailable(tester, 'Let this work reach something new');
      await iWorkInItByHand(tester);
      await theSessionRuns(tester, 'porelo task attach porelo-billing-shell');
    });
    testWidgets('''work an agent is driving can be worked in by hand like any other''', (tester) async {
      await bddSetUp(tester);
      await iSelectTheProject(tester, 'checkout');
      await iSelectTheWork(tester, 'porelo-checkout-shell');
      await iWorkInItByHand(tester);
      await theSessionRuns(tester, 'porelo task attach porelo-checkout-shell');
    });
    testWidgets('''work that has stopped has no session, and points at starting it again''', (tester) async {
      await bddSetUp(tester);
      await iSelectTheWork(tester, 'porelo-billing-audit');
      await theWorkIsDead(tester, 'porelo-billing-audit');
      await iOpenTheCommandFinder(tester);
      await theCommandIsUnavailableBecause(tester, 'Work in it by hand', 'Starting it again brings back the workspace');
    });
    testWidgets('''a session stays where it was opened, and going elsewhere and back finds it there''', (tester) async {
      await bddSetUp(tester);
      await iWorkInItByHand(tester);
      await theSessionIsOnScreen(tester);
      await theWorkPaneIsNotShown(tester);
      await iGoToWhatNeedsAPerson(tester);
      await theSessionIsNotOnScreen(tester);
      await iGoToThePlace(tester, 'work');
      await theSessionIsOnScreen(tester);
    });
    testWidgets('''leaving a session puts somebody back where they were, with the same work selected''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await iWorkInItByHand(tester);
      await iLeaveTheSession(tester);
      await theWorkIsStillSelected(tester, 'porelo-billing-shell');
    });
    testWidgets('''Escape belongs to what is running, and never closes the session''', (tester) async {
      await bddSetUp(tester);
      await iWorkInItByHand(tester);
      await iCloseWhatIsOpen(tester);
      await theSessionIsOnScreen(tester);
      await sessionsAreOpen(tester, 1);
    });
    testWidgets('''a session left and another opened from a tile keeps one open, and stops no work''', (tester) async {
      await bddSetUp(tester);
      await iWorkInItByHand(tester);
      await iLeaveTheSession(tester);
      await iWorkInByHandFromItsTile(tester, 'porelo-billing-audit');
      await sessionsAreOpen(tester, 1);
      await theSessionOnScreenIs(tester, 'porelo-billing-audit');
      await theFirstSessionWasLeft(tester);
      await theWorkWasNeverStopped(tester);
      await iSelectTheProject(tester, 'billing');
      await theSessionIsNotOnScreen(tester);
    });
    testWidgets('''going back to the work finds the same session, not a second one''', (tester) async {
      await bddSetUp(tester);
      await iWorkInItByHand(tester);
      await iGoToWhatNeedsAPerson(tester);
      await iGoToThePlace(tester, 'work');
      await sessionsAreOpen(tester, 1);
      await onlyOneTerminalWasEverOpened(tester);
      await theSessionOnScreenIs(tester, 'porelo-billing-shell');
    });
    testWidgets('''the screen says that closing the window leaves the session running''', (tester) async {
      await bddSetUp(tester);
      await iWorkInItByHand(tester);
      await itSays(tester, 'Closing this window leaves the session running');
    });
    testWidgets('''coming back says how much of the missed time it can show''', (tester) async {
      await bddSetUp(tester);
      await iWorkInItByHand(tester);
      await itSays(tester, 'the last 10000 lines and no more');
    });
    testWidgets('''a session the machine would not open says so, without claiming the work stopped''', (tester) async {
      await bddSetUp(tester);
      await iWorkInItByHand(tester);
      await theSessionEndsWith(tester, 69);
      await itSays(tester, 'The machine would not open a session here');
      await theWorkWasNeverStopped(tester);
    });
    testWidgets('''a connection that never happened is told apart from work that refused''', (tester) async {
      await bddSetUp(tester);
      await iStartWatchingAnotherMachine(tester);
      await iChoose(tester, 'Raise the forward for me');
      await iSayItIsCalled(tester, 'the build machine');
      await iSayItIsAt(tester, 'user@build.example.test');
      await itsSocketThereIs(tester, '/run/user/1001/porelo/porelod.sock');
      await iWatchIt(tester);
      await iSwitchToTheMachine(tester, 'the build machine');
      await iSelectTheProject(tester, 'billing');
      await iSelectTheWork(tester, 'porelo-billing-shell');
      await iWorkInItByHand(tester);
      await theSessionEndsWith(tester, 255);
      await itSays(tester, 'The connection to the build machine failed');
    });
    testWidgets('''leaving a session closes the way in and stops nothing''', (tester) async {
      await bddSetUp(tester);
      await iWorkInItByHand(tester);
      await iLeaveTheSession(tester);
      await noSessionIsOpen(tester);
      await theWorkWasNeverStopped(tester);
    });
    testWidgets('''somebody who typed exit is not told that anything went wrong, and is taken back to the work''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await iWorkInItByHand(tester);
      await theSessionEndsWith(tester, 0);
      await itSays(tester, 'The session has ended. The work is where you left it');
      await itDoesNotSay(tester, 'Closing this window leaves the session running');
      await enoughTimePassesToGoBack(tester);
      await noSessionIsOpen(tester);
    });
  });
}
