// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_the_work.dart';
import './step/the_machine_shown_is.dart';
import './step/i_watch_another_machine_called.dart';
import './step/i_switch_to_the_machine.dart';
import './step/the_project_is_listed.dart';
import './step/i_start_watching_another_machine.dart';
import './step/i_name_the_socket.dart';
import './step/i_copy_the_forwarding_command.dart';
import './step/what_was_copied_is.dart';
import './step/every_machine_is_being_watched.dart';
import './step/i_select_the_project.dart';
import './step/the_tunnel_drops.dart';
import './step/the_machine_is_shown_as_not_answering.dart';
import './step/the_work_is_listed.dart';
import './step/enough_time_passes_for_another_try.dart';
import './step/the_machine_is_shown_as_answering.dart';
import './step/the_machine_is_the_same_node.dart';
import './step/i_open_the_machine_list.dart';
import './step/the_machine_is_shown_as_the_same_node_as.dart';
import './step/no_machine_is_shown_as_the_same_node.dart';
import './step/no_machine_can_say_which_node_it_is.dart';
import './step/i_say_it_is_called.dart';
import './step/i_leave_the_name_field.dart';
import './step/the_name_is_marked_as_taken_by.dart';
import './step/the_machine_cannot_be_watched_yet.dart';

void main() {
  group('''Watching several machines at once, and telling nodes apart''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await iGoToTheWork(tester);
    }

    testWidgets('''which machine an action will act on is always visible''',
        (tester) async {
      await bddSetUp(tester);
      await theMachineShownIs(tester, 'this machine');
    });
    testWidgets(
        '''another machine is watched, and switching moves the whole frame to it''',
        (tester) async {
      await bddSetUp(tester);
      await iWatchAnotherMachineCalled(tester, 'elsewhere');
      await iSwitchToTheMachine(tester, 'elsewhere');
      await theMachineShownIs(tester, 'elsewhere');
      await theProjectIsListed(tester, 'shared');
    });
    testWidgets(
        '''the command that forwards a socket is copied rather than retyped''',
        (tester) async {
      await bddSetUp(tester);
      await iStartWatchingAnotherMachine(tester);
      await iNameTheSocket(tester, '/tmp/porelo-elsewhere.sock');
      await iCopyTheForwardingCommand(tester);
      await whatWasCopiedIs(tester,
          'ssh -L /tmp/porelo-elsewhere.sock:/run/user/<uid>/porelo/porelod.sock user@host -N');
    });
    testWidgets(
        '''every machine is watched at once, not only the one being acted on''',
        (tester) async {
      await bddSetUp(tester);
      await iWatchAnotherMachineCalled(tester, 'elsewhere');
      await everyMachineIsBeingWatched(tester);
    });
    testWidgets('''adding a machine does not move what is being acted on''',
        (tester) async {
      await bddSetUp(tester);
      await iWatchAnotherMachineCalled(tester, 'elsewhere');
      await theMachineShownIs(tester, 'this machine');
    });
    testWidgets(
        '''a lost tunnel reads as a disconnection, never as a machine with nothing on it''',
        (tester) async {
      await bddSetUp(tester);
      await iSelectTheProject(tester, 'checkout');
      await theTunnelDrops(tester);
      await theMachineIsShownAsNotAnswering(tester);
      await theWorkIsListed(tester, 'porelo-checkout-shell');
      await enoughTimePassesForAnotherTry(tester);
      await theMachineIsShownAsAnswering(tester);
    });
    testWidgets(
        '''one node reached two ways is said, rather than counted as two machines''',
        (tester) async {
      await bddSetUp(tester);
      await theMachineIsTheSameNode(tester, 'elsewhere');
      await iWatchAnotherMachineCalled(tester, 'elsewhere');
      await iOpenTheMachineList(tester);
      await theMachineIsShownAsTheSameNodeAs(
          tester, 'elsewhere', 'this machine');
    });
    testWidgets(
        '''two machines that really are two nodes say nothing about each other''',
        (tester) async {
      await bddSetUp(tester);
      await iWatchAnotherMachineCalled(tester, 'elsewhere');
      await iOpenTheMachineList(tester);
      await noMachineIsShownAsTheSameNode(tester);
    });
    testWidgets(
        '''machines that cannot say which node they are are never merged''',
        (tester) async {
      await bddSetUp(tester);
      await noMachineCanSayWhichNodeItIs(tester);
      await iWatchAnotherMachineCalled(tester, 'elsewhere');
      await iOpenTheMachineList(tester);
      await noMachineIsShownAsTheSameNode(tester);
    });
    testWidgets(
        '''a name already watched is marked when the field is left, and nothing is added''',
        (tester) async {
      await bddSetUp(tester);
      await iStartWatchingAnotherMachine(tester);
      await iSayItIsCalled(tester, 'this machine');
      await iLeaveTheNameField(tester);
      await theNameIsMarkedAsTakenBy(tester, 'this machine');
      await theMachineCannotBeWatchedYet(tester);
    });
    testWidgets(
        '''two names that would share one forward count as the same name''',
        (tester) async {
      await bddSetUp(tester);
      await iStartWatchingAnotherMachine(tester);
      await iSayItIsCalled(tester, 'this-machine');
      await iLeaveTheNameField(tester);
      await theNameIsMarkedAsTakenBy(tester, 'this machine');
    });
  });
}
