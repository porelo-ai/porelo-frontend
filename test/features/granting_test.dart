// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_the_work.dart';
import './step/the_store_holds_of_kind_beside.dart';
import './step/i_show_the_vault.dart';
import './step/granting_is_offered.dart';
import './step/granting_is_not_offered.dart';
import './step/i_grant_from_the_store.dart';
import './step/the_machine_was_asked_to_grant.dart';
import './step/the_machine_asks_for_a_decision_on_with_the_code.dart';
import './step/it_says.dart';
import './step/i_open_the_page_in_the_browser_here.dart';
import './step/the_browser_was_given.dart';
import './step/the_machine_says_the_grant_is.dart';
import './step/opening_the_page_is_not_offered.dart';
import './step/i_am_done_granting.dart';
import './step/the_machine_is_asked_again_whether_the_store_is_open.dart';
import './step/the_machine_says_the_grant_is_adding.dart';
import './step/it_does_not_say.dart';
import './step/the_machine_is_reached_over_ssh_as.dart';
import './step/the_machine_asks_for_a_decision_on_answered_on_port.dart';
import './step/a_forward_of_port_is_held.dart';
import './step/opening_the_page_is_offered.dart';
import './step/the_forward_of_port_is_taken_down.dart';
import './step/nothing_was_opened_in_the_browser.dart';
import './step/forwarding_a_port_fails_with.dart';
import './step/opening_the_page_waits_for_its_answers_way_back.dart';
import './step/the_machine_refuses_the_grant_saying.dart';
import './step/the_store_holds_of_kind_granted_by_at.dart';
import './step/the_store_also_holds_of_kind_not_granted.dart';
import './step/granting_is_offered_again.dart';
import './step/the_machine_says_needs_a_grant_for_in.dart';
import './step/i_go_to_what_needs_a_person.dart';
import './step/the_count_of_what_needs_a_person_is.dart';
import './step/somebody_was_told.dart';
import './step/the_machine_says_needs_granting_again_for_in.dart';
import './step/the_machine_says_is_granted.dart';
import './step/nothing_needs_me.dart';
import './step/i_grant_from_what_needs_a_person.dart';

void main() {
  group('''Granting an authorization once, in a browser, for later tasks''',
      () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await iGoToTheWork(tester);
    }

    testWidgets(
        '''an entry that names a service offers to grant it, and one that does not, does not''',
        (tester) async {
      await bddSetUp(tester);
      await theStoreHoldsOfKindBeside(
          tester, 'jira', 'oauth-device', 'a-provider');
      await iShowTheVault(tester);
      await grantingIsOffered(tester, 'jira');
      await grantingIsNotOffered(tester, 'a-provider');
    });
    testWidgets(
        '''a device code's page is shown whole with its code, and opened as it came''',
        (tester) async {
      await bddSetUp(tester);
      await theStoreHoldsOfKindBeside(
          tester, 'jira', 'oauth-device', 'a-provider');
      await iGrantFromTheStore(tester, 'jira');
      await theMachineWasAskedToGrant(tester, 'jira');
      await theMachineAsksForADecisionOnWithTheCode(
          tester,
          'https://auth.example.com/device?user_code=WDJB-MJHT&x=1',
          'WDJB-MJHT');
      await itSays(
          tester, 'https://auth.example.com/device?user_code=WDJB-MJHT&x=1');
      await itSays(tester, 'WDJB-MJHT');
      await itSays(tester, 'It is made there, not here');
      await iOpenThePageInTheBrowserHere(tester);
      await theBrowserWasGiven(
          tester, 'https://auth.example.com/device?user_code=WDJB-MJHT&x=1');
      await itSays(
          tester, 'https://auth.example.com/device?user_code=WDJB-MJHT&x=1');
    });
    testWidgets(
        '''a grant settled in the browser is said, and the store is asked again''',
        (tester) async {
      await bddSetUp(tester);
      await theStoreHoldsOfKindBeside(
          tester, 'jira', 'oauth-device', 'a-provider');
      await iGrantFromTheStore(tester, 'jira');
      await theMachineAsksForADecisionOnWithTheCode(
          tester, 'https://auth.example.com/device', 'WDJB-MJHT');
      await theMachineSaysTheGrantIs(tester, 'granted');
      await itSays(tester, 'Granted. It is kept in the vault');
      await openingThePageIsNotOffered(tester);
      await iAmDoneGranting(tester);
      await theMachineIsAskedAgainWhetherTheStoreIsOpen(tester);
    });
    testWidgets(
        '''Outline: how a grant ends is said in words ('refused', 'Refused in the browser. Nothing was granted.')''',
        (tester) async {
      await bddSetUp(tester);
      await theStoreHoldsOfKindBeside(
          tester, 'jira', 'oauth-device', 'a-provider');
      await iGrantFromTheStore(tester, 'jira');
      await theMachineAsksForADecisionOnWithTheCode(
          tester, 'https://auth.example.com/device', 'WDJB-MJHT');
      await theMachineSaysTheGrantIs(tester, 'refused');
      await itSays(tester, 'Refused in the browser. Nothing was granted.');
    });
    testWidgets(
        '''Outline: how a grant ends is said in words ('expired', 'The question expired before anybody decided.')''',
        (tester) async {
      await bddSetUp(tester);
      await theStoreHoldsOfKindBeside(
          tester, 'jira', 'oauth-device', 'a-provider');
      await iGrantFromTheStore(tester, 'jira');
      await theMachineAsksForADecisionOnWithTheCode(
          tester, 'https://auth.example.com/device', 'WDJB-MJHT');
      await theMachineSaysTheGrantIs(tester, 'expired');
      await itSays(tester, 'The question expired before anybody decided.');
    });
    testWidgets(
        '''Outline: how a grant ends is said in words ('failed', 'It failed: the service answered invalid_client')''',
        (tester) async {
      await bddSetUp(tester);
      await theStoreHoldsOfKindBeside(
          tester, 'jira', 'oauth-device', 'a-provider');
      await iGrantFromTheStore(tester, 'jira');
      await theMachineAsksForADecisionOnWithTheCode(
          tester, 'https://auth.example.com/device', 'WDJB-MJHT');
      await theMachineSaysTheGrantIs(tester, 'failed');
      await itSays(tester, 'It failed: the service answered invalid_client');
    });
    testWidgets(
        '''a grant the machine adds words to says them, and one the machine refused is not said as the person's''',
        (tester) async {
      await bddSetUp(tester);
      await theStoreHoldsOfKindBeside(
          tester, 'jira', 'oauth-device', 'a-provider');
      await iGrantFromTheStore(tester, 'jira');
      await theMachineAsksForADecisionOnWithTheCode(
          tester, 'https://auth.example.com/device', 'WDJB-MJHT');
      await theMachineSaysTheGrantIsAdding(tester, 'granted',
          'the service gave a token that does not expire, which removing it here cannot revoke');
      await itSays(tester,
          'and the next task uses it. the service gave a token that does not expire');
    });
    testWidgets(
        '''a grant the machine would not keep is said as the machine's refusal''',
        (tester) async {
      await bddSetUp(tester);
      await theStoreHoldsOfKindBeside(
          tester, 'jira', 'oauth-device', 'a-provider');
      await iGrantFromTheStore(tester, 'jira');
      await theMachineAsksForADecisionOnWithTheCode(
          tester, 'https://auth.example.com/device', 'WDJB-MJHT');
      await theMachineSaysTheGrantIsAdding(
          tester, 'refused', 'the service granted no refresh token');
      await itSays(tester,
          'did not keep what the service granted: the service granted no refresh token');
      await itDoesNotSay(tester, 'Refused in the browser');
    });
    testWidgets(
        '''a redirect's page is offered only once its answer can reach the machine, and the forward goes after''',
        (tester) async {
      await bddSetUp(tester);
      await theMachineIsReachedOverSshAs(tester, 'alice@vm');
      await theStoreHoldsOfKindBeside(
          tester, 'forge', 'oauth-code', 'a-provider');
      await iGrantFromTheStore(tester, 'forge');
      await theMachineAsksForADecisionOnAnsweredOnPort(
          tester, 'https://forge.example/authorize?state=s1', '8765');
      await aForwardOfPortIsHeld(tester, '8765');
      await openingThePageIsOffered(tester);
      await theMachineSaysTheGrantIs(tester, 'granted');
      await theForwardOfPortIsTakenDown(tester, '8765');
    });
    testWidgets(
        '''Outline: a link that is not a web address is shown and never offered to open ('file:///etc/passwd')''',
        (tester) async {
      await bddSetUp(tester);
      await theStoreHoldsOfKindBeside(
          tester, 'jira', 'oauth-device', 'a-provider');
      await iGrantFromTheStore(tester, 'jira');
      await theMachineAsksForADecisionOnWithTheCode(
          tester, 'file:///etc/passwd', 'WDJB-MJHT');
      await itSays(tester, 'file:///etc/passwd');
      await openingThePageIsNotOffered(tester);
      await nothingWasOpenedInTheBrowser(tester);
    });
    testWidgets(
        '''Outline: a link that is not a web address is shown and never offered to open ('ftp://auth.example.com/device')''',
        (tester) async {
      await bddSetUp(tester);
      await theStoreHoldsOfKindBeside(
          tester, 'jira', 'oauth-device', 'a-provider');
      await iGrantFromTheStore(tester, 'jira');
      await theMachineAsksForADecisionOnWithTheCode(
          tester, 'ftp://auth.example.com/device', 'WDJB-MJHT');
      await itSays(tester, 'ftp://auth.example.com/device');
      await openingThePageIsNotOffered(tester);
      await nothingWasOpenedInTheBrowser(tester);
    });
    testWidgets(
        '''Outline: a link that is not a web address is shown and never offered to open ('https:///device')''',
        (tester) async {
      await bddSetUp(tester);
      await theStoreHoldsOfKindBeside(
          tester, 'jira', 'oauth-device', 'a-provider');
      await iGrantFromTheStore(tester, 'jira');
      await theMachineAsksForADecisionOnWithTheCode(
          tester, 'https:///device', 'WDJB-MJHT');
      await itSays(tester, 'https:///device');
      await openingThePageIsNotOffered(tester);
      await nothingWasOpenedInTheBrowser(tester);
    });
    testWidgets(
        '''a redirect whose answer cannot be forwarded is not offered to open, and says why''',
        (tester) async {
      await bddSetUp(tester);
      await theMachineIsReachedOverSshAs(tester, 'alice@vm');
      await forwardingAPortFailsWith(
          tester, 'Port 8765 is already in use on this computer');
      await theStoreHoldsOfKindBeside(
          tester, 'forge', 'oauth-code', 'a-provider');
      await iGrantFromTheStore(tester, 'forge');
      await theMachineAsksForADecisionOnAnsweredOnPort(
          tester, 'https://forge.example/authorize?state=s1', '8765');
      await openingThePageWaitsForItsAnswersWayBack(tester);
      await itSays(tester, 'Port 8765 is already in use on this computer');
    });
    testWidgets(
        '''a grant that cannot be asked for says why in the machine's words''',
        (tester) async {
      await bddSetUp(tester);
      await theStoreHoldsOfKindBeside(
          tester, 'jira', 'oauth-device', 'a-provider');
      await iGrantFromTheStore(tester, 'jira');
      await theMachineRefusesTheGrantSaying(
          tester, 'the service at auth.example.com could not be reached');
      await itSays(tester,
          'It could not be asked for: the service at auth.example.com could not be reached');
    });
    testWidgets(
        '''an entry says who granted it and when, or that nobody has yet''',
        (tester) async {
      await bddSetUp(tester);
      await theStoreHoldsOfKindGrantedByAt(
          tester, 'jira', 'oauth-device', 'alice', '2026-09-30T05:40:00Z');
      await theStoreAlsoHoldsOfKindNotGranted(tester, 'forge', 'oauth-code');
      await iShowTheVault(tester);
      await itSays(
          tester, 'oauth-device · granted by alice, 2026-09-30T05:40:00Z');
      await itSays(tester, 'oauth-code · not granted yet');
      await grantingIsOfferedAgain(tester, 'jira');
    });
    testWidgets(
        '''an authorization work waits for is in what needs a person, and told''',
        (tester) async {
      await bddSetUp(tester);
      await theMachineSaysNeedsAGrantForIn(
          tester, 'jira', 'sokar-checkout-shell', 'checkout');
      await iGoToWhatNeedsAPerson(tester);
      await itSays(tester, 'jira needs a grant for sokar-checkout-shell');
      await itSays(tester, 'Nobody has granted it yet');
      await theCountOfWhatNeedsAPersonIs(tester, '1 need you');
      await somebodyWasTold(
          tester, 'jira needs a grant for sokar-checkout-shell');
    });
    testWidgets('''a grant the service ended says it needs granting again''',
        (tester) async {
      await bddSetUp(tester);
      await theMachineSaysNeedsGrantingAgainForIn(
          tester, 'jira', 'sokar-checkout-shell', 'checkout');
      await iGoToWhatNeedsAPerson(tester);
      await itSays(tester, 'the service has ended the grant');
    });
    testWidgets(
        '''an authorization granted anywhere leaves what needs a person''',
        (tester) async {
      await bddSetUp(tester);
      await theMachineSaysNeedsAGrantForIn(
          tester, 'jira', 'sokar-checkout-shell', 'checkout');
      await iGoToWhatNeedsAPerson(tester);
      await theMachineSaysIsGranted(tester, 'jira');
      await itDoesNotSay(tester, 'jira needs a grant');
      await nothingNeedsMe(tester);
    });
    testWidgets('''an authorization is granted from what needs a person''',
        (tester) async {
      await bddSetUp(tester);
      await theMachineSaysNeedsAGrantForIn(
          tester, 'jira', 'sokar-checkout-shell', 'checkout');
      await iGoToWhatNeedsAPerson(tester);
      await iGrantFromWhatNeedsAPerson(tester, 'jira');
      await theMachineWasAskedToGrant(tester, 'jira');
    });
  });
}
