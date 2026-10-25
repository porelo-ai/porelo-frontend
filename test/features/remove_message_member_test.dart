// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_the_work.dart';
import './step/i_select_the_project.dart';
import './step/the_project_has_a_conversation_over_reaching_ready.dart';
import './step/has_joined_the_conversation_of.dart';
import './step/i_choose_the_command.dart';
import './step/i_ask_to_remove_room_member.dart';
import './step/the_room_lists.dart';
import './step/i_press.dart';
import './step/i_join.dart';
import './step/i_give_a_new_password.dart';
import './step/join_is_offered_again.dart';
import './step/i_am_done_with_the_messages.dart';
import './step/room_member_has_left_at_the_machine.dart';
import './step/removal_is_refused_for_absent_member.dart';
import './step/the_room_still_displays_member.dart';
import './step/the_transport_keeps_account_because.dart';
import './step/the_kept_account_explanation_is_shown.dart';
import './step/removing_a_room_member_is_refused_with.dart';
import './step/removal_is_refused_with.dart';
import './step/the_machine_cannot_remove_room_members_yet.dart';
import './step/room_member_removal_is_unavailable.dart';

void main() {
  group('''Removing a person from a project room''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await iGoToTheWork(tester);
      await iSelectTheProject(tester, 'checkout');
      await theProjectHasAConversationOverReachingReady(tester, 'checkout', 'matrix', '127.0.0.1:8008');
      await hasJoinedTheConversationOf(tester, 'anna', 'checkout');
      await hasJoinedTheConversationOf(tester, 'bea', 'checkout');
      await iChooseTheCommand(tester, 'Messages and the project’s room');
    }

    testWidgets('''confirmation removes only the selected person''', (tester) async {
      await bddSetUp(tester);
      await iAskToRemoveRoomMember(tester, 'anna');
      await theRoomLists(tester, 'anna,bea');
      await iPress(tester, 'Remove');
      await theRoomLists(tester, 'bea');
    });
    testWidgets('''cancelling keeps the account in the room''', (tester) async {
      await bddSetUp(tester);
      await iAskToRemoveRoomMember(tester, 'anna');
      await iPress(tester, 'Cancel');
      await theRoomLists(tester, 'anna,bea');
    });
    testWidgets('''removing the current account offers Join again''', (tester) async {
      await bddSetUp(tester);
      await iJoin(tester, 'anna');
      await iGiveANewPassword(tester);
      await iAskToRemoveRoomMember(tester, 'anna');
      await iPress(tester, 'Remove');
      await theRoomLists(tester, 'bea');
      await joinIsOfferedAgain(tester);
      await iAmDoneWithTheMessages(tester);
      await iChooseTheCommand(tester, 'Messages and the project’s room');
      await joinIsOfferedAgain(tester);
    });
    testWidgets('''a member removed elsewhere is shown as a refusal''', (tester) async {
      await bddSetUp(tester);
      await roomMemberHasLeftAtTheMachine(tester, 'anna', 'checkout');
      await iAskToRemoveRoomMember(tester, 'anna');
      await iPress(tester, 'Remove');
      await removalIsRefusedForAbsentMember(tester, 'anna');
      await theRoomStillDisplaysMember(tester, 'anna');
    });
    testWidgets('''a kept account shows the transport explanation''', (tester) async {
      await bddSetUp(tester);
      await theTransportKeepsAccountBecause(
        tester,
        '@anna:localhost',
        'It belongs to another room too; its account remains.',
      );
      await iAskToRemoveRoomMember(tester, 'anna');
      await iPress(tester, 'Remove');
      await theRoomLists(tester, 'bea');
      await theKeptAccountExplanationIsShown(tester);
    });
    testWidgets('''a transport refusal preserves the member''', (tester) async {
      await bddSetUp(tester);
      await removingARoomMemberIsRefusedWith(tester, 'The homeserver refused this operation.');
      await iAskToRemoveRoomMember(tester, 'anna');
      await iPress(tester, 'Remove');
      await removalIsRefusedWith(tester, 'The homeserver refused this operation.');
      await theRoomLists(tester, 'anna,bea');
    });
    testWidgets('''an older daemon disables only Remove after answering''', (tester) async {
      await bddSetUp(tester);
      await theMachineCannotRemoveRoomMembersYet(tester);
      await iAskToRemoveRoomMember(tester, 'anna');
      await iPress(tester, 'Remove');
      await roomMemberRemovalIsUnavailable(tester);
      await theRoomLists(tester, 'anna,bea');
      await iJoin(tester, 'cara');
      await theRoomLists(tester, 'anna,bea,cara');
    });
  });
}
