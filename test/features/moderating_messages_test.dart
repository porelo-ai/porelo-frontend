// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/has_a_message_held_for_saying.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_what_needs_a_person.dart';
import './step/what_needs_a_person_shows_a_message_from.dart';
import './step/the_count_of_what_needs_a_person_is.dart';
import './step/has_a_message_held_for_while_i_watch.dart';
import './step/i_read_the_message_from.dart';
import './step/the_message_reads_exactly.dart';
import './step/nothing_in_the_message_can_be_pressed.dart';
import './step/it_says.dart';
import './step/i_release_the_message.dart';
import './step/the_machine_was_told_to_release_of.dart';
import './step/the_message_is_no_longer_open.dart';
import './step/what_needs_a_person_shows_no_message.dart';
import './step/nothing_needs_me.dart';
import './step/i_refuse_the_message.dart';
import './step/the_machine_was_told_to_refuse_of.dart';
import './step/it_does_not_say.dart';
import './step/i_refuse_the_message_saying.dart';
import './step/the_refusal_gave_the_reason.dart';
import './step/i_go_to_the_work.dart';
import './step/i_select_the_project.dart';
import './step/i_choose_from_the_menu_of_the_tile.dart';
import './step/i_put_in_its_inbox.dart';
import './step/a_person_told.dart';
import './step/the_status_line_mentions.dart';
import './step/putting_it_in_its_inbox_is_not_offered_yet.dart';
import './step/i_cancel_the_words.dart';
import './step/nobody_told_any_task_anything.dart';
import './step/i_leave_the_message_for_now.dart';
import './step/nothing_was_decided_about_any_message.dart';
import './step/has_a_message_the_filter_refused_for_saying.dart';
import './step/the_row_of_the_message_from_previews.dart';
import './step/the_message_can_be_delivered_despite_the_filter_or_kept_refused.dart';
import './step/has_a_message_the_filter_could_not_check.dart';
import './step/the_message_was_decided_somewhere_else.dart';
import './step/the_message_cannot_be_decided_here.dart';
import './step/the_machine_cannot_list_held_messages.dart';
import './step/may_talk_to_in.dart';
import './step/may_talk_to_in_held.dart';
import './step/the_peer_is_not_held.dart';
import './step/the_peer_is_held.dart';
import './step/may_talk_to_through_the_projects_conversation.dart';
import './step/i_hold_everything_for.dart';
import './step/the_machine_was_told_to_hold_of_in.dart';
import './step/the_machine_says_of_was.dart';
import './step/has_a_message_held_coming_in_from_saying.dart';
import './step/i_follow_what_happens_for_the_whole_project.dart';

void main() {
  group('''Reading and deciding about what work says to other work''', () {
    testWidgets(
        '''a message held before the interface started is in what needs a person, and counted''',
        (tester) async {
      await aBackendWithWorkOnIt(tester);
      await hasAMessageHeldForSaying(tester, 'sokar-checkout-shell', 'reviewer',
          'please look at the diff');
      await theAppIsRunning(tester);
      await iGoToWhatNeedsAPerson(tester);
      await whatNeedsAPersonShowsAMessageFrom(tester, 'sokar-checkout-shell');
      await theCountOfWhatNeedsAPersonIs(tester, '1 need you');
    });
    testWidgets(
        '''a message held while the interface watches arrives without asking''',
        (tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await iGoToWhatNeedsAPerson(tester);
      await hasAMessageHeldForWhileIWatch(
          tester, 'sokar-checkout-shell', 'reviewer');
      await whatNeedsAPersonShowsAMessageFrom(tester, 'sokar-checkout-shell');
    });
    testWidgets(
        '''a held message is read in full, as text, and nothing in it is interpreted''',
        (tester) async {
      await aBackendWithWorkOnIt(tester);
      await hasAMessageHeldForSaying(tester, 'sokar-checkout-shell', 'reviewer',
          '**now** [see](https://evil.example/x) <b>here</b>');
      await theAppIsRunning(tester);
      await iGoToWhatNeedsAPerson(tester);
      await iReadTheMessageFrom(tester, 'sokar-checkout-shell');
      await theMessageReadsExactly(
          tester, '**now** [see](https://evil.example/x) <b>here</b>');
      await nothingInTheMessageCanBePressed(tester);
      await itSays(tester, 'Held until somebody reads it');
    });
    testWidgets('''releasing a message names the message that was read''',
        (tester) async {
      await aBackendWithWorkOnIt(tester);
      await hasAMessageHeldForSaying(tester, 'sokar-checkout-shell', 'reviewer',
          'please look at the diff');
      await theAppIsRunning(tester);
      await iGoToWhatNeedsAPerson(tester);
      await iReadTheMessageFrom(tester, 'sokar-checkout-shell');
      await iReleaseTheMessage(tester);
      await theMachineWasToldToReleaseOf(
          tester, 'msg-1.json', 'sokar-checkout-shell');
      await itSays(tester,
          'Released. It goes out on the next pass, unless its peer is set to refuse everything.');
      await theMessageIsNoLongerOpen(tester);
      await whatNeedsAPersonShowsNoMessage(tester);
      await nothingNeedsMe(tester);
    });
    testWidgets('''refusing a message refuses it for good''', (tester) async {
      await aBackendWithWorkOnIt(tester);
      await hasAMessageHeldForSaying(tester, 'sokar-checkout-shell', 'reviewer',
          'please look at the diff');
      await theAppIsRunning(tester);
      await iGoToWhatNeedsAPerson(tester);
      await iReadTheMessageFrom(tester, 'sokar-checkout-shell');
      await iRefuseTheMessage(tester);
      await theMachineWasToldToRefuseOf(
          tester, 'msg-1.json', 'sokar-checkout-shell');
      await itSays(tester, 'Refused for good');
      await itDoesNotSay(tester, 'with your words');
    });
    testWidgets(
        '''a refusal can say why, and the one that wrote it is told those words''',
        (tester) async {
      await aBackendWithWorkOnIt(tester);
      await hasAMessageHeldForSaying(tester, 'sokar-checkout-shell', 'reviewer',
          'please look at the diff');
      await theAppIsRunning(tester);
      await iGoToWhatNeedsAPerson(tester);
      await iReadTheMessageFrom(tester, 'sokar-checkout-shell');
      await iRefuseTheMessageSaying(tester, 'not before the tests pass');
      await theMachineWasToldToRefuseOf(
          tester, 'msg-1.json', 'sokar-checkout-shell');
      await theRefusalGaveTheReason(tester, 'not before the tests pass');
      await itSays(tester, 'The task that wrote it is told, with your words.');
    });
    testWidgets(
        '''a person writes to a task's own agent, straight into its inbox''',
        (tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await iGoToTheWork(tester);
      await iSelectTheProject(tester, 'checkout');
      await iChooseFromTheMenuOfTheTile(
          tester, 'Write to its agent', 'sokar-checkout-migrate');
      await iPutInItsInbox(tester, 'stop the migration, the schema changed');
      await aPersonTold(tester, 'sokar-checkout-migrate',
          'stop the migration, the schema changed');
      await theStatusLineMentions(
          tester, 'Written into the inbox of sokar-checkout-migrate');
    });
    testWidgets(
        '''writing to a task's agent needs words, and cancelling writes nothing''',
        (tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await iChooseFromTheMenuOfTheTile(
          tester, 'Write to its agent', 'sokar-checkout-migrate');
      await puttingItInItsInboxIsNotOfferedYet(tester);
      await iCancelTheWords(tester);
      await nobodyToldAnyTaskAnything(tester);
    });
    testWidgets('''leaving a message for now decides nothing''',
        (tester) async {
      await aBackendWithWorkOnIt(tester);
      await hasAMessageHeldForSaying(tester, 'sokar-checkout-shell', 'reviewer',
          'please look at the diff');
      await theAppIsRunning(tester);
      await iGoToWhatNeedsAPerson(tester);
      await iReadTheMessageFrom(tester, 'sokar-checkout-shell');
      await iLeaveTheMessageForNow(tester);
      await nothingWasDecidedAboutAnyMessage(tester);
      await whatNeedsAPersonShowsAMessageFrom(tester, 'sokar-checkout-shell');
    });
    testWidgets(
        '''a held message shows the start of its text in its row, one the filter refused never does''',
        (tester) async {
      await aBackendWithWorkOnIt(tester);
      await hasAMessageHeldForSaying(tester, 'sokar-checkout-shell', 'reviewer',
          'please look at the diff');
      await hasAMessageTheFilterRefusedForSaying(
          tester, 'sokar-billing-shell', 'partner', 'key AKIA0000');
      await theAppIsRunning(tester);
      await iGoToWhatNeedsAPerson(tester);
      await theRowOfTheMessageFromPreviews(
          tester, 'sokar-checkout-shell', 'please look at the diff');
      await theRowOfTheMessageFromPreviews(tester, 'sokar-billing-shell', '');
    });
    testWidgets(
        '''a message the filter refused is read in full, and can be delivered despite the filter''',
        (tester) async {
      await aBackendWithWorkOnIt(tester);
      await hasAMessageTheFilterRefusedForSaying(
          tester, 'sokar-checkout-shell', 'partner', 'key AKIA0000');
      await theAppIsRunning(tester);
      await iGoToWhatNeedsAPerson(tester);
      await iReadTheMessageFrom(tester, 'sokar-checkout-shell');
      await theMessageReadsExactly(tester, 'key AKIA0000');
      await itSays(tester, 'rule aws-key');
      await itSays(tester, 'checks it again with its own filter');
      await theMessageCanBeDeliveredDespiteTheFilterOrKeptRefused(tester);
      await iReleaseTheMessage(tester);
      await theMachineWasToldToReleaseOf(
          tester, 'msg-1.json', 'sokar-checkout-shell');
      await itSays(tester, 'Delivered despite the filter');
    });
    testWidgets(
        '''a message the filter could not check is not offered for delivery''',
        (tester) async {
      await aBackendWithWorkOnIt(tester);
      await hasAMessageTheFilterCouldNotCheck(tester, 'sokar-checkout-shell');
      await theAppIsRunning(tester);
      await iGoToWhatNeedsAPerson(tester);
      await whatNeedsAPersonShowsNoMessage(tester);
      await nothingNeedsMe(tester);
    });
    testWidgets(
        '''a message decided somewhere else meanwhile is said to be gone, and nothing is decided''',
        (tester) async {
      await aBackendWithWorkOnIt(tester);
      await hasAMessageHeldForSaying(tester, 'sokar-checkout-shell', 'reviewer',
          'please look at the diff');
      await theAppIsRunning(tester);
      await iGoToWhatNeedsAPerson(tester);
      await theMessageWasDecidedSomewhereElse(tester);
      await iReadTheMessageFrom(tester, 'sokar-checkout-shell');
      await itSays(tester, 'It is no longer there');
      await theMessageCannotBeDecidedHere(tester);
    });
    testWidgets(
        '''a machine that cannot list held messages says so, rather than showing none''',
        (tester) async {
      await aBackendWithWorkOnIt(tester);
      await theMachineCannotListHeldMessages(tester);
      await theAppIsRunning(tester);
      await iGoToWhatNeedsAPerson(tester);
      await itSays(tester, 'cannot list the messages held for a person');
    });
    testWidgets(
        '''the peers of a task's project are listed, each with its brake, and the rules are said to be in the project's file''',
        (tester) async {
      await aBackendWithWorkOnIt(tester);
      await mayTalkToIn(
          tester, 'sokar-checkout-migrate', 'reviewer', 'vouched', 'prompt');
      await mayTalkToInHeld(
          tester, 'sokar-checkout-migrate', 'partner', 'external', 'allow');
      await theAppIsRunning(tester);
      await iChooseFromTheMenuOfTheTile(tester,
          "Hold its project's messages to a peer", 'sokar-checkout-migrate');
      await thePeerIsNotHeld(tester, 'reviewer');
      await thePeerIsHeld(tester, 'partner');
      await itSays(tester,
          'Holding applies to every task of checkout, including one started later');
      await itSays(tester, "is set in the project's project.yml");
      await itSays(tester, 'in its repository');
      await itDoesNotSay(tester, 'under Settings on its page');
      await itDoesNotSay(
          tester, 'External: what arrives from it is checked again here');
    });
    testWidgets('''who a peer in the project's conversation is, is said''',
        (tester) async {
      await aBackendWithWorkOnIt(tester);
      await mayTalkToThroughTheProjectsConversation(
          tester, 'sokar-checkout-migrate', 'alice', 'external');
      await mayTalkToThroughTheProjectsConversation(
          tester, 'sokar-checkout-migrate', 'reader', 'vouched');
      await theAppIsRunning(tester);
      await iChooseFromTheMenuOfTheTile(tester,
          "Hold its project's messages to a peer", 'sokar-checkout-migrate');
      await itSays(tester,
          'Whoever reads this project’s conversation in a matrix client, by the name alice');
      await itSays(tester, 'Another piece of work in this project');
    });
    testWidgets(
        '''holding everything for a peer is asked of the machine, and the peer is shown as waiting''',
        (tester) async {
      await aBackendWithWorkOnIt(tester);
      await mayTalkToIn(
          tester, 'sokar-checkout-migrate', 'reviewer', 'vouched', 'allow');
      await theAppIsRunning(tester);
      await iChooseFromTheMenuOfTheTile(tester,
          "Hold its project's messages to a peer", 'sokar-checkout-migrate');
      await iHoldEverythingFor(tester, 'reviewer');
      await theMachineWasToldToHoldOfIn(
          tester, 'reviewer', 'sokar-checkout-migrate', 'checkout');
      await thePeerIsHeld(tester, 'reviewer');
    });
    testWidgets(
        '''a task whose project names no peers is said to talk to nobody''',
        (tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await iChooseFromTheMenuOfTheTile(tester,
          "Hold its project's messages to a peer", 'sokar-checkout-migrate');
      await itSays(tester, 'names no peers, so it may talk to nobody');
    });
    testWidgets(
        '''what happened to a task's messages is followed live, for that task only, and never what they said''',
        (tester) async {
      await aBackendWithWorkOnIt(tester);
      await mayTalkToIn(
          tester, 'sokar-checkout-migrate', 'reviewer', 'vouched', 'prompt');
      await theAppIsRunning(tester);
      await theMachineSaysOfWas(
          tester, 'msg-7.json', 'sokar-checkout-migrate', 'overridden');
      await theMachineSaysOfWas(
          tester, 'msg-8.json', 'sokar-checkout-shell', 'sent');
      await iChooseFromTheMenuOfTheTile(tester,
          "Hold its project's messages to a peer", 'sokar-checkout-migrate');
      await itSays(tester,
          'msg-7.json (reviewer) delivered by a person despite the filter');
      await itDoesNotSay(tester, 'msg-8.json');
      await itSays(tester, 'the machine does not stream what came before');
    });
    testWidgets('''a held message says which way it was going''',
        (tester) async {
      await aBackendWithWorkOnIt(tester);
      await hasAMessageHeldForSaying(tester, 'sokar-checkout-shell', 'reviewer',
          'please look at the diff');
      await hasAMessageHeldComingInFromSaying(
          tester, 'sokar-checkout-shell', 'partner', 'here is the file');
      await theAppIsRunning(tester);
      await iGoToWhatNeedsAPerson(tester);
      await itSays(tester, 'going out from sokar-checkout-shell to reviewer');
      await itSays(tester, 'coming in from partner to sokar-checkout-shell');
      await itSays(tester,
          'Whoever wrote it has sent it already; it only waits to reach sokar-checkout-shell.');
      await itSays(
          tester, 'Read it, and decide whether sokar-checkout-shell gets it');
    });
    testWidgets(
        '''a peer says how many messages with it wait for a person now''',
        (tester) async {
      await aBackendWithWorkOnIt(tester);
      await mayTalkToIn(
          tester, 'sokar-checkout-migrate', 'reviewer', 'vouched', 'prompt');
      await hasAMessageHeldForSaying(
          tester, 'sokar-checkout-migrate', 'reviewer', 'first');
      await hasAMessageHeldForSaying(
          tester, 'sokar-checkout-migrate', 'reviewer', 'second');
      await theAppIsRunning(tester);
      await iChooseFromTheMenuOfTheTile(tester,
          "Hold its project's messages to a peer", 'sokar-checkout-migrate');
      await itSays(tester, '2 messages with it wait for a person now');
    });
    testWidgets(
        '''what happened is followed for the whole project on request, and never another project's''',
        (tester) async {
      await aBackendWithWorkOnIt(tester);
      await mayTalkToIn(
          tester, 'sokar-checkout-migrate', 'reviewer', 'vouched', 'prompt');
      await theAppIsRunning(tester);
      await theMachineSaysOfWas(
          tester, 'msg-7.json', 'sokar-checkout-migrate', 'held');
      await theMachineSaysOfWas(
          tester, 'msg-8.json', 'sokar-checkout-shell', 'sent');
      await theMachineSaysOfWas(
          tester, 'msg-9.json', 'sokar-billing-shell', 'sent');
      await iChooseFromTheMenuOfTheTile(tester,
          "Hold its project's messages to a peer", 'sokar-checkout-migrate');
      await itSays(tester, 'msg-7.json');
      await itDoesNotSay(tester, 'msg-8.json');
      await iFollowWhatHappensForTheWholeProject(tester);
      await itSays(tester, 'msg-8.json');
      await itDoesNotSay(tester, 'msg-9.json');
    });
    testWidgets(
        '''releasing a message held on its way in says it reaches the task''',
        (tester) async {
      await aBackendWithWorkOnIt(tester);
      await hasAMessageHeldComingInFromSaying(
          tester, 'sokar-checkout-shell', 'partner', 'here is the review');
      await theAppIsRunning(tester);
      await iGoToWhatNeedsAPerson(tester);
      await iReadTheMessageFrom(tester, 'sokar-checkout-shell');
      await iReleaseTheMessage(tester);
      await itSays(tester,
          'Released. The next pass checks it again, as every arrival is checked');
      await itSays(tester, 'one held for its signature is held again');
      await itDoesNotSay(tester, 'goes out');
    });
    testWidgets(
        '''holding everything for a peer says a person's release still goes''',
        (tester) async {
      await aBackendWithWorkOnIt(tester);
      await mayTalkToIn(
          tester, 'sokar-checkout-migrate', 'reviewer', 'vouched', 'prompt');
      await theAppIsRunning(tester);
      await iChooseFromTheMenuOfTheTile(tester,
          "Hold its project's messages to a peer", 'sokar-checkout-migrate');
      await itSays(tester,
          'Nothing goes to it unless a person releases it, or until this is off again');
    });
  });
}
