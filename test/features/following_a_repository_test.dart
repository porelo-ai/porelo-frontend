// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_the_work.dart';
import './step/the_next_follow_is_refused_as.dart';
import './step/i_follow_a_repository.dart';
import './step/i_name_it_at.dart';
import './step/the_verified_project_admin_signers_are_available.dart';
import './step/i_follow_it.dart';
import './step/it_says.dart';
import './step/there_is_no_project.dart';
import './step/the_next_follow_finds_a_rewritten_history.dart';
import './step/the_follow_accepted_no_rewrite.dart';
import './step/i_take_the_rewritten_history.dart';
import './step/the_follow_accepted_the_rewrite.dart';
import './step/the_credential_check_answers.dart';
import './step/no_follow_was_sent.dart';
import './step/setting_up_its_connection_is_offered.dart';
import './step/the_machine_is_reached_over_ssh_as.dart';
import './step/i_open_the_vault_from_the_follow.dart';
import './step/a_terminal_runs_on_the_machine.dart';
import './step/i_show_its_connection_from_the_follow.dart';
import './step/the_connections_of_the_machine_are_open.dart';
import './step/the_follow_still_names_at.dart';
import './step/i_show_the_connections_after_the_follow.dart';
import './step/the_machine_has_never_met_the_host.dart';
import './step/trusting_is_not_offered_until_a_key_is_chosen.dart';
import './step/following_it_again_is_not_offered.dart';
import './step/i_trust_the_host_key_from_the_follow.dart';
import './step/the_machine_trusts_for_and_nothing_else.dart';
import './step/the_follow_was_made_again_with_nothing_retyped.dart';
import './step/then_offers_other_keys.dart';
import './step/the_follow_was_not_made_again.dart';
import './step/the_machine_remembers_another_key_of.dart';
import './step/trusting_a_host_key_is_not_offered.dart';
import './step/i_choose.dart';
import './step/the_machine_has_no_credential_check.dart';
import './step/the_follow_was_sent_with_verified_project_admin_signers.dart';

void main() {
  group('''A project comes to a machine by following its repository''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await iGoToTheWork(tester);
    }

    testWidgets('''a commit the machine will not take is said, and no project is made of it''', (tester) async {
      await bddSetUp(tester);
      await theNextFollowIsRefusedAs(tester, 'NOT_SIGNED');
      await iFollowARepository(tester);
      await iNameItAt(tester, 'payments', 'git@example.org:payments.git');
      await theVerifiedProjectAdminSignersAreAvailable(tester);
      await iFollowIt(tester);
      await itSays(tester, 'is not signed');
      await thereIsNoProject(tester, 'payments');
    });
    testWidgets('''a rewritten history is taken only as a second decision''', (tester) async {
      await bddSetUp(tester);
      await theNextFollowFindsARewrittenHistory(tester);
      await iFollowARepository(tester);
      await iNameItAt(tester, 'payments', 'git@example.org:payments.git');
      await theVerifiedProjectAdminSignersAreAvailable(tester);
      await iFollowIt(tester);
      await itSays(tester, 'Nothing here can tell which');
      await theFollowAcceptedNoRewrite(tester);
      await iTakeTheRewrittenHistory(tester);
      await theFollowAcceptedTheRewrite(tester);
    });
    testWidgets('''a repository nothing is set up to reach is not followed, and its connection is offered''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theCredentialCheckAnswers(tester, 'NO_CREDENTIAL');
      await iFollowARepository(tester);
      await iNameItAt(tester, 'payments', 'git@example.org:payments.git');
      await theVerifiedProjectAdminSignersAreAvailable(tester);
      await iFollowIt(tester);
      await itSays(tester, 'Nothing on this machine is set up to reach this address');
      await noFollowWasSent(tester);
      await settingUpItsConnectionIsOffered(tester);
    });
    testWidgets('''a credential in a shut vault offers to open it, and follows nothing''', (tester) async {
      await bddSetUp(tester);
      await theCredentialCheckAnswers(tester, 'VAULT_LOCKED');
      await theMachineIsReachedOverSshAs(tester, 'alice@vm');
      await iFollowARepository(tester);
      await iNameItAt(tester, 'payments', 'git@example.org:payments.git');
      await theVerifiedProjectAdminSignersAreAvailable(tester);
      await iFollowIt(tester);
      await noFollowWasSent(tester);
      await iOpenTheVaultFromTheFollow(tester);
      await aTerminalRunsOnTheMachine(tester, 'ssh -t alice@vm porelo vault unlock');
    });
    testWidgets('''a connection whose value is not there offers the connection, and follows nothing''', (tester) async {
      await bddSetUp(tester);
      await theCredentialCheckAnswers(tester, 'MISSING_VALUE');
      await iFollowARepository(tester);
      await iNameItAt(tester, 'payments', 'git@example.org:payments.git');
      await theVerifiedProjectAdminSignersAreAvailable(tester);
      await iFollowIt(tester);
      await itSays(tester, 'its value is not there');
      await noFollowWasSent(tester);
      await iShowItsConnectionFromTheFollow(tester);
      await theConnectionsOfTheMachineAreOpen(tester);
      await iFollowARepository(tester);
      await theFollowStillNamesAt(tester, 'payments', 'git@example.org:payments.git');
    });
    testWidgets('''a repository that turned the machine away offers its connections''', (tester) async {
      await bddSetUp(tester);
      await theCredentialCheckAnswers(tester, 'READY');
      await theNextFollowIsRefusedAs(tester, 'UNREACHABLE');
      await iFollowARepository(tester);
      await iNameItAt(tester, 'payments', 'git@example.org:payments.git');
      await theVerifiedProjectAdminSignersAreAvailable(tester);
      await iFollowIt(tester);
      await itSays(tester, 'The repository cannot be reached');
      await iShowTheConnectionsAfterTheFollow(tester);
      await theConnectionsOfTheMachineAreOpen(tester);
    });
    testWidgets('''a follow turned away for want of a credential says so in words''', (tester) async {
      await bddSetUp(tester);
      await theNextFollowIsRefusedAs(tester, 'NO_CREDENTIAL');
      await iFollowARepository(tester);
      await iNameItAt(tester, 'payments', 'git@example.org:payments.git');
      await theVerifiedProjectAdminSignersAreAvailable(tester);
      await iFollowIt(tester);
      await itSays(tester, 'the machine says nothing it holds reaches the repository');
    });
    testWidgets('''a credential that is there and cannot be used offers its connection''', (tester) async {
      await bddSetUp(tester);
      await theCredentialCheckAnswers(tester, 'UNUSABLE_VALUE');
      await iFollowARepository(tester);
      await iNameItAt(tester, 'payments', 'git@example.org:payments.git');
      await theVerifiedProjectAdminSignersAreAvailable(tester);
      await iFollowIt(tester);
      await itSays(tester, 'its value cannot be used');
      await noFollowWasSent(tester);
      await iShowItsConnectionFromTheFollow(tester);
      await theConnectionsOfTheMachineAreOpen(tester);
    });
    testWidgets('''a host never met is said as that, never as a missing credential''', (tester) async {
      await bddSetUp(tester);
      await theNextFollowIsRefusedAs(tester, 'UNKNOWN_HOST_KEY');
      await iFollowARepository(tester);
      await iNameItAt(tester, 'payments', 'git@example.org:payments.git');
      await theVerifiedProjectAdminSignersAreAvailable(tester);
      await iFollowIt(tester);
      await itSays(tester, 'this machine has never met that host');
    });
    testWidgets('''a host never met shows its keys, and the one chosen is trusted before following again''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theMachineHasNeverMetTheHost(tester, 'example.org');
      await iFollowARepository(tester);
      await iNameItAt(tester, 'payments', 'git@example.org:payments.git');
      await theVerifiedProjectAdminSignersAreAvailable(tester);
      await iFollowIt(tester);
      await itSays(tester, 'this machine has never met that host');
      await itSays(tester, 'SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU');
      await itSays(tester, 'not with what this screen says');
      await trustingIsNotOfferedUntilAKeyIsChosen(tester);
      await followingItAgainIsNotOffered(tester);
      await iTrustTheHostKeyFromTheFollow(tester, 'SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU');
      await theMachineTrustsForAndNothingElse(
        tester,
        'SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU',
        'example.org',
      );
      await theFollowWasMadeAgainWithNothingRetyped(tester);
      await itSays(tester, 'Following');
    });
    testWidgets('''a host that offers other keys by the time one is trusted records nothing''', (tester) async {
      await bddSetUp(tester);
      await theMachineHasNeverMetTheHost(tester, 'example.org');
      await iFollowARepository(tester);
      await iNameItAt(tester, 'payments', 'git@example.org:payments.git');
      await theVerifiedProjectAdminSignersAreAvailable(tester);
      await iFollowIt(tester);
      await thenOffersOtherKeys(tester, 'example.org');
      await iTrustTheHostKeyFromTheFollow(tester, 'SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU');
      await itSays(tester, 'offers no key with that fingerprint right now');
      await theFollowWasNotMadeAgain(tester);
    });
    testWidgets('''a host key that changed is said as possible interception, and nothing is offered to trust''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theMachineRemembersAnotherKeyOf(tester, 'example.org');
      await iFollowARepository(tester);
      await iNameItAt(tester, 'payments', 'git@example.org:payments.git');
      await theVerifiedProjectAdminSignersAreAvailable(tester);
      await iFollowIt(tester);
      await itSays(tester, 'somebody in between');
      await itSays(tester, 'SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU');
      await trustingAHostKeyIsNotOffered(tester);
      await followingItAgainIsNotOffered(tester);
    });
    testWidgets('''what was typed is gone once the follow is left''', (tester) async {
      await bddSetUp(tester);
      await iFollowARepository(tester);
      await iNameItAt(tester, 'payments', 'git@example.org:payments.git');
      await iChoose(tester, 'Leave it');
      await iFollowARepository(tester);
      await theFollowStillNamesAt(tester, '', '');
    });
    testWidgets('''a machine older than the check is still followed, and says itself what is wrong''', (tester) async {
      await bddSetUp(tester);
      await theMachineHasNoCredentialCheck(tester);
      await iFollowARepository(tester);
      await iNameItAt(tester, 'payments', 'git@example.org:payments.git');
      await theVerifiedProjectAdminSignersAreAvailable(tester);
      await iFollowIt(tester);
      await theFollowWasSentWithVerifiedProjectAdminSigners(tester);
    });
    testWidgets('''a local repository needs nothing, and is followed''', (tester) async {
      await bddSetUp(tester);
      await theCredentialCheckAnswers(tester, 'NOT_NEEDED');
      await iFollowARepository(tester);
      await iNameItAt(tester, 'payments', '/srv/git/payments');
      await theVerifiedProjectAdminSignersAreAvailable(tester);
      await iFollowIt(tester);
      await theFollowWasSentWithVerifiedProjectAdminSigners(tester);
    });
  });
}
