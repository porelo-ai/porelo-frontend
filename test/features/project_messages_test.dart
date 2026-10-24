// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_the_work.dart';
import './step/i_select_the_project.dart';
import './step/i_open_the_command_finder.dart';
import './step/the_command_is_unavailable_because.dart';
import './step/the_machine_is_reached_over_ssh_as.dart';
import './step/the_project_has_a_conversation_over_reaching_ready.dart';
import './step/i_choose_the_command.dart';
import './step/i_join.dart';
import './step/the_machine_was_asked_to_let_join.dart';
import './step/it_says.dart';
import './step/what_a_walk_writes_down_does_not_hold.dart';
import './step/the_is_blanked_in_a_walks_picture.dart';
import './step/a_forward_of_port_is_held.dart';
import './step/i_am_done_with_the_messages.dart';
import './step/the_forward_of_port_is_still_held.dart';
import './step/the_project_header_says.dart';
import './step/the_next_forward_is_refused_because.dart';
import './step/the_forward_of_port_drops_and_is_tried_again.dart';
import './step/i_go_to_what_needs_a_person.dart';
import './step/the_homeserver_notice_for_names_machine.dart';
import './step/has_joined_the_conversation_of.dart';
import './step/i_give_a_new_password.dart';
import './step/the_machine_was_last_asked_to_let_join_with_a_new_password.dart';
import './step/nothing_was_forwarded.dart';
import './step/joining_is_not_offered_yet.dart';

void main() {
  group('''A project's conversation, and a person joining it''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await iGoToTheWork(tester);
      await iSelectTheProject(tester, 'checkout');
    }

    testWidgets('''a project with no conversation is not offered its messages''', (tester) async {
      await bddSetUp(tester);
      await iOpenTheCommandFinder(tester);
      await theCommandIsUnavailableBecause(tester, 'Messages and the project’s room', 'checkout has no conversation');
    });
    testWidgets('''a person joins, and their login is shown once with the homeserver forwarded here''', (tester) async {
      await bddSetUp(tester);
      await theMachineIsReachedOverSshAs(tester, 'alice@vm');
      await theProjectHasAConversationOverReachingReady(tester, 'checkout', 'matrix', '127.0.0.1:8008');
      await iSelectTheProject(tester, 'checkout');
      await iChooseTheCommand(tester, 'Messages and the project’s room');
      await iJoin(tester, 'anna');
      await theMachineWasAskedToLetJoin(tester, 'anna', 'checkout');
      await itSays(tester, 'pw-1-once');
      await whatAWalkWritesDownDoesNotHold(tester, 'pw-1-once');
      await theIsBlankedInAWalksPicture(tester, 'login password');
      await itSays(tester, '#porelo-checkout:localhost');
      await itSays(tester, 'Matrix ID');
      await itSays(tester, 'Homeserver URL');
      await itSays(tester, 'anna, as @anna:localhost');
      await aForwardOfPortIsHeld(tester, '8008');
      await itSays(tester, 'port 8008 is forwarded from this computer while this window runs');
      await iAmDoneWithTheMessages(tester);
      await theForwardOfPortIsStillHeld(tester, '8008');
      await iChooseTheCommand(tester, 'Messages and the project’s room');
      await itSays(
        tester,
        'A Matrix client here reaches its homeserver at http://127.0.0.1:8008, forwarded while this window runs.',
      );
    });
    testWidgets(
      '''the homeserver's address is said on the project's page, and a forward that cannot be raised needs you''',
      (tester) async {
        await bddSetUp(tester);
        await theMachineIsReachedOverSshAs(tester, 'alice@vm');
        await theProjectHasAConversationOverReachingReady(tester, 'checkout', 'matrix', '127.0.0.1:8008');
        await iSelectTheProject(tester, 'checkout');
        await iChooseTheCommand(tester, 'Messages and the project’s room');
        await iJoin(tester, 'anna');
        await iAmDoneWithTheMessages(tester);
        await theProjectHeaderSays(tester, 'A Matrix client here reaches its homeserver at http://127.0.0.1:8008.');
        await theNextForwardIsRefusedBecause(tester, 'Port 8008 is already in use on this computer.');
        await theForwardOfPortDropsAndIsTriedAgain(tester, '8008');
        await iGoToWhatNeedsAPerson(tester);
        await itSays(tester, 'The homeserver of checkout is not reachable from here');
        await theHomeserverNoticeForNamesMachine(tester, 'checkout', 'vm');
        await itSays(tester, 'Port 8008 is already in use on this computer.');
        await itSays(tester, 'Try again');
      },
    );
    testWidgets('''a person who has joined already is offered a new password, and nothing else''', (tester) async {
      await bddSetUp(tester);
      await theProjectHasAConversationOverReachingReady(tester, 'checkout', 'matrix', '127.0.0.1:8008');
      await hasJoinedTheConversationOf(tester, 'anna', 'checkout');
      await iChooseTheCommand(tester, 'Messages and the project’s room');
      await iJoin(tester, 'anna');
      await itSays(tester, 'anna has joined already, as @anna:localhost');
      await iGiveANewPassword(tester);
      await theMachineWasLastAskedToLetJoinWithANewPassword(tester, 'anna', 'checkout');
      await itSays(tester, 'pw-2-once');
    });
    testWidgets('''a machine that is this computer forwards nothing for its homeserver''', (tester) async {
      await bddSetUp(tester);
      await theProjectHasAConversationOverReachingReady(tester, 'checkout', 'matrix', '127.0.0.1:8008');
      await iChooseTheCommand(tester, 'Messages and the project’s room');
      await iJoin(tester, 'anna');
      await itSays(tester, 'The homeserver is on this computer, at http://127.0.0.1:8008.');
      await nothingWasForwarded(tester);
    });
    testWidgets('''nobody is joined without a name''', (tester) async {
      await bddSetUp(tester);
      await theProjectHasAConversationOverReachingReady(tester, 'checkout', 'matrix', '127.0.0.1:8008');
      await iChooseTheCommand(tester, 'Messages and the project’s room');
      await joiningIsNotOfferedYet(tester);
    });
  });
}
