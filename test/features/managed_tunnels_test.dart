// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_the_work.dart';
import './step/i_start_watching_another_machine.dart';
import './step/i_choose.dart';
import './step/i_say_it_is_called.dart';
import './step/i_say_it_is_at.dart';
import './step/its_socket_there_is.dart';
import './step/i_watch_it.dart';
import './step/the_forward_was_raised_for.dart';
import './step/the_machine_says_the_forward_is_raised_here.dart';
import './step/i_open_the_machine_dialog.dart';
import './step/watching_it_is_not_offered_yet.dart';
import './step/i_watch_another_machine_called.dart';
import './step/nothing_was_raised_for.dart';
import './step/the_machine_does_not_say_the_forward_is_raised_here.dart';
import './step/raising_a_forward_will_fail_with.dart';
import './step/the_machine_says.dart';
import './step/nothing_answers_on_that_machine.dart';
import './step/i_switch_to_the_machine.dart';
import './step/i_ask_to_start_porelo_on_this_machine.dart';
import './step/nothing_was_started_on_that_machine.dart';
import './step/i_agree_to_start_it.dart';
import './step/the_machine_was_asked_to_start.dart';
import './step/the_session_recorded.dart';
import './step/the_machine_answers_again.dart';
import './step/i_do_not_agree_to_start_it.dart';
import './step/the_machine_can_answer_again.dart';
import './step/i_open_the_command_finder.dart';
import './step/the_command_is_unavailable_because.dart';
import './step/i_ask_to_stop_porelo_on_this_machine.dart';
import './step/it_says.dart';
import './step/nothing_was_stopped_on_that_machine.dart';
import './step/i_agree_to_stop_it.dart';
import './step/the_machine_was_asked_to_stop.dart';
import './step/the_machine_no_longer_answers.dart';
import './step/the_command_is_offered.dart';
import './step/i_do_not_agree_to_stop_it.dart';
import './step/i_close_the_interface.dart';
import './step/no_forward_this_interface_raised_is_still_running.dart';
import './step/nothing_was_torn_down_for.dart';
import './step/its_socket_there_is_not_filled_in.dart';
import './step/the_account_logs_in_as_uid.dart';
import './step/the_machine_was_asked_who_logs_in_as.dart';
import './step/the_forward_was_raised_through_to.dart';
import './step/the_wizard_set_up_the_machine.dart';
import './step/i_ask_to_forget_this_machine.dart';
import './step/i_forget_it.dart';
import './step/the_ssh_config_still_has_the_host.dart';
import './step/the_key_of_is_still_there.dart';
import './step/i_also_remove_its_host_entry.dart';
import './step/i_also_delete_its_key.dart';
import './step/the_ssh_config_no_longer_has_the_host.dart';
import './step/the_ssh_config_as_it_was_before_is_kept.dart';
import './step/the_key_of_is_gone.dart';
import './step/another_host_entry_uses_the_key_of.dart';
import './step/deleting_its_key_cannot_be_chosen.dart';
import './step/the_machine_is_reached_through_a_host_entry_written_by_hand.dart';
import './step/the_machine_is_no_longer_watched.dart';

void main() {
  group('''Raising and dropping the forward that reaches a machine''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await iGoToTheWork(tester);
    }

    testWidgets('''a machine is described by where it is, and the forward is raised here''', (tester) async {
      await bddSetUp(tester);
      await iStartWatchingAnotherMachine(tester);
      await iChoose(tester, 'Raise the forward for me');
      await iSayItIsCalled(tester, 'the build machine');
      await iSayItIsAt(tester, 'user@build.example.test');
      await itsSocketThereIs(tester, '/run/user/1001/porelo/porelod.sock');
      await iWatchIt(tester);
      await theForwardWasRaisedFor(tester, 'the build machine');
      await theMachineSaysTheForwardIsRaisedHere(tester, 'the build machine');
    });
    testWidgets('''how it is reached is chosen, never assumed''', (tester) async {
      await bddSetUp(tester);
      await iOpenTheMachineDialog(tester);
      await iSayItIsCalled(tester, 'the build machine');
      await watchingItIsNotOfferedYet(tester);
    });
    testWidgets('''a machine whose socket is already forwarded has nothing raised for it''', (tester) async {
      await bddSetUp(tester);
      await iWatchAnotherMachineCalled(tester, 'elsewhere');
      await nothingWasRaisedFor(tester, 'elsewhere');
      await theMachineDoesNotSayTheForwardIsRaisedHere(tester, 'elsewhere');
    });
    testWidgets('''a forward that cannot be raised says what the transport said''', (tester) async {
      await bddSetUp(tester);
      await raisingAForwardWillFailWith(tester, 'Host key verification failed.');
      await iStartWatchingAnotherMachine(tester);
      await iChoose(tester, 'Raise the forward for me');
      await iSayItIsCalled(tester, 'the build machine');
      await iSayItIsAt(tester, 'user@build.example.test');
      await itsSocketThereIs(tester, '/run/user/1001/porelo/porelod.sock');
      await iWatchIt(tester);
      await theMachineSays(tester, 'the build machine', 'Host key verification failed.');
    });
    testWidgets('''a watched machine that is silent can be started from its menu, once somebody agrees''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await nothingAnswersOnThatMachine(tester);
      await iStartWatchingAnotherMachine(tester);
      await iChoose(tester, 'Raise the forward for me');
      await iSayItIsCalled(tester, 'the build machine');
      await iSayItIsAt(tester, 'user@build.example.test');
      await itsSocketThereIs(tester, '/run/user/1001/porelo/porelod.sock');
      await iWatchIt(tester);
      await iSwitchToTheMachine(tester, 'the build machine');
      await iAskToStartPoreloOnThisMachine(tester);
      await nothingWasStartedOnThatMachine(tester);
      await iAgreeToStartIt(tester);
      await theMachineWasAskedToStart(tester, 'setsid porelod');
      await theSessionRecorded(tester, 'Start Porelo on user@build.example.test');
      await theMachineAnswersAgain(tester, 'the build machine');
    });
    testWidgets('''a start nobody agreed to runs nothing''', (tester) async {
      await bddSetUp(tester);
      await nothingAnswersOnThatMachine(tester);
      await iStartWatchingAnotherMachine(tester);
      await iChoose(tester, 'Raise the forward for me');
      await iSayItIsCalled(tester, 'the build machine');
      await iSayItIsAt(tester, 'user@build.example.test');
      await itsSocketThereIs(tester, '/run/user/1001/porelo/porelod.sock');
      await iWatchIt(tester);
      await iSwitchToTheMachine(tester, 'the build machine');
      await iAskToStartPoreloOnThisMachine(tester);
      await iDoNotAgreeToStartIt(tester);
      await nothingWasStartedOnThatMachine(tester);
      await theMachineCanAnswerAgain(tester);
      await theMachineAnswersAgain(tester, 'the build machine');
    });
    testWidgets('''a machine that answers is offered no start at all''', (tester) async {
      await bddSetUp(tester);
      await iStartWatchingAnotherMachine(tester);
      await iChoose(tester, 'Raise the forward for me');
      await iSayItIsCalled(tester, 'the build machine');
      await iSayItIsAt(tester, 'user@build.example.test');
      await itsSocketThereIs(tester, '/run/user/1001/porelo/porelod.sock');
      await iWatchIt(tester);
      await iSwitchToTheMachine(tester, 'the build machine');
      await iOpenTheCommandFinder(tester);
      await theCommandIsUnavailableBecause(tester, 'Start Porelo on this machine', 'already answering');
    });
    testWidgets('''a machine somebody else forwards is offered no start, because there is no host''', (tester) async {
      await bddSetUp(tester);
      await iWatchAnotherMachineCalled(tester, 'elsewhere');
      await iSwitchToTheMachine(tester, 'elsewhere');
      await iOpenTheCommandFinder(tester);
      await theCommandIsUnavailableBecause(tester, 'Start Porelo on this machine', 'somebody else');
    });
    testWidgets('''a machine that answers can be stopped from its menu, told first what stopping costs''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await iStartWatchingAnotherMachine(tester);
      await iChoose(tester, 'Raise the forward for me');
      await iSayItIsCalled(tester, 'the build machine');
      await iSayItIsAt(tester, 'user@build.example.test');
      await itsSocketThereIs(tester, '/run/user/1001/porelo/porelod.sock');
      await iWatchIt(tester);
      await iSwitchToTheMachine(tester, 'the build machine');
      await iAskToStopPoreloOnThisMachine(tester);
      await itSays(tester, 'What runs there goes on running');
      await itSays(tester, 'nothing here watches it');
      await itSays(tester, 'goes unanswered and runs out');
      await nothingWasStoppedOnThatMachine(tester);
      await iAgreeToStopIt(tester);
      await theMachineWasAskedToStop(tester, 'systemctl --user stop porelod');
      await theSessionRecorded(tester, 'Stop Porelo on user@build.example.test');
      await theMachineNoLongerAnswers(tester, 'the build machine');
      await iOpenTheCommandFinder(tester);
      await theCommandIsOffered(tester, 'Start Porelo on this machine');
      await theMachineCanAnswerAgain(tester);
      await theMachineAnswersAgain(tester, 'the build machine');
    });
    testWidgets('''a stop nobody agreed to runs nothing''', (tester) async {
      await bddSetUp(tester);
      await iStartWatchingAnotherMachine(tester);
      await iChoose(tester, 'Raise the forward for me');
      await iSayItIsCalled(tester, 'the build machine');
      await iSayItIsAt(tester, 'user@build.example.test');
      await itsSocketThereIs(tester, '/run/user/1001/porelo/porelod.sock');
      await iWatchIt(tester);
      await iSwitchToTheMachine(tester, 'the build machine');
      await iAskToStopPoreloOnThisMachine(tester);
      await iDoNotAgreeToStopIt(tester);
      await nothingWasStoppedOnThatMachine(tester);
      await theMachineAnswersAgain(tester, 'the build machine');
    });
    testWidgets('''a machine that is not answering is offered no stop''', (tester) async {
      await bddSetUp(tester);
      await nothingAnswersOnThatMachine(tester);
      await iStartWatchingAnotherMachine(tester);
      await iChoose(tester, 'Raise the forward for me');
      await iSayItIsCalled(tester, 'the build machine');
      await iSayItIsAt(tester, 'user@build.example.test');
      await itsSocketThereIs(tester, '/run/user/1001/porelo/porelod.sock');
      await iWatchIt(tester);
      await iSwitchToTheMachine(tester, 'the build machine');
      await iOpenTheCommandFinder(tester);
      await theCommandIsUnavailableBecause(tester, 'Stop Porelo on this machine', 'not answering');
      await theMachineCanAnswerAgain(tester);
      await theMachineAnswersAgain(tester, 'the build machine');
    });
    testWidgets('''a machine somebody else forwards is offered no stop, because there is no host''', (tester) async {
      await bddSetUp(tester);
      await iWatchAnotherMachineCalled(tester, 'elsewhere');
      await iSwitchToTheMachine(tester, 'elsewhere');
      await iOpenTheCommandFinder(tester);
      await theCommandIsUnavailableBecause(tester, 'Stop Porelo on this machine', 'somebody else');
    });
    testWidgets('''closing the interface leaves no forward it raised still running''', (tester) async {
      await bddSetUp(tester);
      await iStartWatchingAnotherMachine(tester);
      await iChoose(tester, 'Raise the forward for me');
      await iSayItIsCalled(tester, 'the build machine');
      await iSayItIsAt(tester, 'user@build.example.test');
      await itsSocketThereIs(tester, '/run/user/1001/porelo/porelod.sock');
      await iWatchIt(tester);
      await iCloseTheInterface(tester);
      await noForwardThisInterfaceRaisedIsStillRunning(tester);
    });
    testWidgets('''a forward the interface did not raise is never torn down by it''', (tester) async {
      await bddSetUp(tester);
      await iWatchAnotherMachineCalled(tester, 'elsewhere');
      await iCloseTheInterface(tester);
      await nothingWasTornDownFor(tester, 'elsewhere');
    });
    testWidgets('''the socket on the other machine is asked for, never guessed''', (tester) async {
      await bddSetUp(tester);
      await iStartWatchingAnotherMachine(tester);
      await iChoose(tester, 'Raise the forward for me');
      await itsSocketThereIsNotFilledIn(tester);
    });
    testWidgets('''a socket left empty is asked of the machine when it is watched, and the forward goes there''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theAccountLogsInAsUid(tester, 1007);
      await iStartWatchingAnotherMachine(tester);
      await iChoose(tester, 'Raise the forward for me');
      await iSayItIsCalled(tester, 'the build machine');
      await iSayItIsAt(tester, 'user@build.example.test');
      await iWatchIt(tester);
      await theMachineWasAskedWhoLogsInAs(tester, 'user@build.example.test');
      await theForwardWasRaisedThroughTo(tester, 'user@build.example.test', '/run/user/1007/porelo/porelod.sock');
    });
    testWidgets(
      '''forgetting a machine the wizard set up offers its Host entry and key, and removes neither unasked''',
      (tester) async {
        await bddSetUp(tester);
        await theWizardSetUpTheMachine(tester, 'build');
        await iSwitchToTheMachine(tester, 'build');
        await iAskToForgetThisMachine(tester);
        await itSays(tester, 'Also remove Host porelo-build from ~/.ssh/config');
        await itSays(tester, 'Also delete its key');
        await iForgetIt(tester);
        await theSshConfigStillHasTheHost(tester, 'porelo-build');
        await theKeyOfIsStillThere(tester, 'build');
      },
    );
    testWidgets('''forgetting a machine the wizard set up removes its Host entry and key when asked''', (tester) async {
      await bddSetUp(tester);
      await theWizardSetUpTheMachine(tester, 'build');
      await iSwitchToTheMachine(tester, 'build');
      await iAskToForgetThisMachine(tester);
      await iAlsoRemoveItsHostEntry(tester);
      await iAlsoDeleteItsKey(tester);
      await iForgetIt(tester);
      await theSshConfigNoLongerHasTheHost(tester, 'porelo-build');
      await theSshConfigAsItWasBeforeIsKept(tester);
      await theKeyOfIsGone(tester, 'build');
    });
    testWidgets('''a key another Host entry uses is not offered for deleting''', (tester) async {
      await bddSetUp(tester);
      await theWizardSetUpTheMachine(tester, 'build');
      await anotherHostEntryUsesTheKeyOf(tester, 'build');
      await iSwitchToTheMachine(tester, 'build');
      await iAskToForgetThisMachine(tester);
      await itSays(tester, 'Another entry in ~/.ssh/config uses it, so it stays.');
      await deletingItsKeyCannotBeChosen(tester);
    });
    testWidgets('''a Host entry written by hand is never offered for removal''', (tester) async {
      await bddSetUp(tester);
      await theMachineIsReachedThroughAHostEntryWrittenByHand(tester, 'handmade');
      await iSwitchToTheMachine(tester, 'handmade');
      await iAskToForgetThisMachine(tester);
      await theSshConfigStillHasTheHost(tester, 'handmade');
      await theMachineIsNoLongerWatched(tester, 'handmade');
    });
  });
}
