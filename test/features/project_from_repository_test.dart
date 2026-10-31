// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_the_work.dart';
import './step/i_pick_a_project_from_one_of_my_repositories.dart';
import './step/the_repositories_are_offered.dart';
import './step/the_forge_reaches_as_an_admin_and_without_admin_rights.dart';
import './step/the_keychain_here_keeps_the_token_for_the_forge.dart';
import './step/it_says.dart';
import './step/the_forges_repository_is_listed.dart';
import './step/i_follow_a_repository.dart';
import './step/i_pick_one_of_my_repositories_instead.dart';
import './step/the_forge_also_accepts_the_token.dart';
import './step/i_open_my_forges.dart';
import './step/i_add_the_forge_at_with_the_token.dart';
import './step/the_forges_set_up_here_are.dart';
import './step/the_keychain_keeps_for_the_forge_entry.dart';
import './step/the_forges_and_are_set_up_both_reaching_it.dart';
import './step/no_token_is_asked_for.dart';
import './step/i_choose_the_forge.dart';
import './step/i_change_to_be_called_with_the_token.dart';
import './step/the_machine_follows_the_project_from.dart';
import './step/the_forge_holds_the_key_at_from_a_machine_that_is_gone.dart';
import './step/i_remove_the_forge.dart';
import './step/i_press.dart';
import './step/the_keychain_here_keeps_no_token.dart';
import './step/holds_the_project_with_the_work_repository_at.dart';
import './step/the_machines_porelo_cannot_work_on_a_project_from_here_yet.dart';
import './step/i_choose_the_command.dart';
import './step/i_connect_the_forge_with_the_token.dart';
import './step/i_look_at_the_forges_repository.dart';
import './step/i_start_working_on_on_the_machine.dart';
import './step/working_on_it_on_the_machine_is_not_offered.dart';
import './step/nothing_was_asked_of_the_machine_to_work_on_it.dart';
import './step/i_select_the_project.dart';
import './step/i_open_the_command_finder.dart';
import './step/the_command_is_unavailable_because.dart';
import './step/i_follow_by_its_address_instead.dart';
import './step/following_a_repository_by_hand_is_open.dart';
import './step/the_keychain_here_keeps_the_token.dart';
import './step/it_does_not_say.dart';
import './step/the_forge_form_takes_no_token.dart';
import './step/the_forges_repository_says.dart';
import './step/binding_is_not_offered_for.dart';
import './step/has_a_projectyml.dart';
import './step/i_use_as_a_project.dart';
import './step/binding_the_machine_is_offered.dart';
import './step/the_forge_answers_only_when_told.dart';
import './step/the_forge_answers.dart';
import './step/i_search_the_repositories_for.dart';
import './step/the_forges_repository_is_not_listed.dart';
import './step/i_forget_the_token_here.dart';
import './step/i_bind_the_machine_to.dart';
import './step/no_deploy_key_calls_were_made.dart';
import './step/the_machine_followed_pinned_to_the_persons_key.dart';
import './step/the_machine_never_saw_the_forges_token.dart';
import './step/the_next_follow_is_refused_as.dart';
import './step/the_forge_holds_no_key_at.dart';
import './step/the_forge_lists_my_signing_keys_and.dart';
import './step/the_machine_followed_pinned_to_every_signing_key_at_the_forge.dart';
import './step/the_machine_has_never_met_the_host.dart';
import './step/the_machine_trusts_for_and_nothing_else.dart';
import './step/i_close_the_binding_and_the_repositories.dart';
import './step/the_machine_was_cleared_after_a_dry_run.dart';
import './step/the_forge_holds_no_key_of_the_machine_at_or.dart';
import './step/is_a_project_of_its_own.dart';
import './step/i_remove_the_machine.dart';
import './step/the_machine_pins_when_it_follows.dart';
import './step/the_project_is_the_one_shown.dart';
import './step/the_machines_gate_holds_the_change_saying.dart';
import './step/i_look_at_the_changes_waiting_at_the_machine.dart';
import './step/merging_the_change_is_not_offered_yet.dart';
import './step/i_review_the_change.dart';
import './step/i_merge_the_change_signed.dart';
import './step/the_change_was_merged_here_signed_with.dart';
import './step/the_machine_was_told_landed_on.dart';
import './step/the_upstream_does_not_hold_what_is_merged_yet.dart';
import './step/the_change_is_still_listed.dart';
import './step/the_rail_lists_in_this_order.dart';
import './step/i_go_to_the_forges.dart';
import './step/the_repository_is_worked_on_on.dart';
import './step/i_choose_from_the_card_of.dart';
import './step/default_holds_at.dart';

void main() {
  group('''A project from a repository a person already has on a forge''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
    }

    testWidgets('''a project from a repository is on screen, beside following one''', (tester) async {
      await bddSetUp(tester);
      await iGoToTheWork(tester);
      await iPickAProjectFromOneOfMyRepositories(tester);
      await theRepositoriesAreOffered(tester);
    });
    testWidgets('''with a token kept from before, the repositories are listed and the dialog stays''', (tester) async {
      await bddSetUp(tester);
      await iGoToTheWork(tester);
      await theForgeReachesAsAnAdminAndWithoutAdminRights(tester, 'acme/api', 'acme/web');
      await theKeychainHereKeepsTheTokenForTheForge(tester, 'ghp_accepted');
      await iPickAProjectFromOneOfMyRepositories(tester);
      await theRepositoriesAreOffered(tester);
      await itSays(tester, 'GitHub');
      await itSays(tester, 'login alice');
      await theForgesRepositoryIsListed(tester, 'acme/api');
    });
    testWidgets('''following a project by hand points to picking one of the person's repositories''', (tester) async {
      await bddSetUp(tester);
      await iGoToTheWork(tester);
      await iFollowARepository(tester);
      await iPickOneOfMyRepositoriesInstead(tester);
      await theRepositoriesAreOffered(tester);
    });
    testWidgets('''a second forge is set up beside the first, each host token kept under its own entry''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theForgeReachesAsAnAdminAndWithoutAdminRights(tester, 'acme/api', 'acme/web');
      await theKeychainHereKeepsTheTokenForTheForge(tester, 'ghp_accepted');
      await theForgeAlsoAcceptsTheToken(tester, 'ghp_work');
      await iOpenMyForges(tester);
      await iAddTheForgeAtWithTheToken(tester, 'GitHub work', 'git.work.example.org', 'ghp_work');
      await theForgesSetUpHereAre(tester, 'GitHub, GitHub work');
      await theKeychainKeepsForTheForgeEntry(tester, 'ghp_work', 'GitHub work');
      await theKeychainKeepsForTheForgeEntry(tester, 'ghp_accepted', 'GitHub');
      await itSays(tester, 'git.work.example.org · token chosen explicitly');
    });
    testWidgets('''with two forges set up, the repositories are shown once one is chosen''', (tester) async {
      await bddSetUp(tester);
      await iGoToTheWork(tester);
      await theForgeReachesAsAnAdminAndWithoutAdminRights(tester, 'acme/api', 'acme/web');
      await theForgesAndAreSetUpBothReachingIt(tester, 'GitHub', 'GitHub work');
      await iPickAProjectFromOneOfMyRepositories(tester);
      await itSays(tester, 'Connect a forge');
      await noTokenIsAskedFor(tester);
      await iChooseTheForge(tester, 'GitHub work');
      await itSays(tester, 'GitHub work');
      await itSays(tester, 'login alice');
      await theForgesRepositoryIsListed(tester, 'acme/api');
    });
    testWidgets('''a forge is renamed and given a new token, through the terminal prompt''', (tester) async {
      await bddSetUp(tester);
      await theKeychainHereKeepsTheTokenForTheForge(tester, 'ghp_accepted');
      await theForgeAlsoAcceptsTheToken(tester, 'ghp_renewed');
      await iOpenMyForges(tester);
      await iChangeToBeCalledWithTheToken(tester, 'GitHub', 'GitHub private', 'ghp_renewed');
      await theForgesSetUpHereAre(tester, 'GitHub private');
      await theKeychainKeepsForTheForgeEntry(tester, 'ghp_renewed', 'GitHub private');
    });
    testWidgets('''removing a forge leaves machine vaults and legacy keys alone''', (tester) async {
      await bddSetUp(tester);
      await theKeychainHereKeepsTheTokenForTheForge(tester, 'ghp_accepted');
      await theMachineFollowsTheProjectFrom(tester, 'checkout', 'git@github.com:acme/api.git');
      await theForgeHoldsTheKeyAtFromAMachineThatIsGone(tester, 'porelo vm api/api', 'acme/api');
      await iOpenMyForges(tester);
      await iRemoveTheForge(tester, 'GitHub');
      await itSays(tester, 'Projects your machines follow use it: acme/api');
      await iPress(tester, 'Remove it');
      await theForgesSetUpHereAre(tester, '');
      await theKeychainHereKeepsNoToken(tester);
    });
    testWidgets('''a machine whose Porelo cannot be bound says so before anything is asked of it''', (tester) async {
      await bddSetUp(tester);
      await theForgeReachesAsAnAdminAndWithoutAdminRights(tester, 'acme/api', 'acme/web');
      await holdsTheProjectWithTheWorkRepositoryAt(
        tester,
        'acme/api',
        'api',
        'backend',
        'git@github.com:acme/backend.git',
      );
      await theMachinesPoreloCannotWorkOnAProjectFromHereYet(tester);
      await iChooseTheCommand(tester, 'A project from a repository you have');
      await iConnectTheForgeWithTheToken(tester, 'ghp_accepted');
      await iLookAtTheForgesRepository(tester, 'acme/api');
      await iStartWorkingOnOnTheMachine(tester, 'acme/api');
      await itSays(tester, 'runs a Porelo that cannot do this yet');
      await workingOnItOnTheMachineIsNotOffered(tester);
      await nothingWasAskedOfTheMachineToWorkOnIt(tester);
    });
    testWidgets('''a project whose repository is on a forge not set up here says so in its menu''', (tester) async {
      await bddSetUp(tester);
      await iGoToTheWork(tester);
      await theMachineFollowsTheProjectFrom(tester, 'checkout', 'git@gitlab.example.org:acme/api.git');
      await iSelectTheProject(tester, 'checkout');
      await iOpenTheCommandFinder(tester);
      await theCommandIsUnavailableBecause(
        tester,
        'Its machines and keys at its forge',
        'gitlab.example.org, which is not set up here',
      );
    });
    testWidgets('''a repository no forge holds is followed by its address from the same dialog''', (tester) async {
      await bddSetUp(tester);
      await iGoToTheWork(tester);
      await iPickAProjectFromOneOfMyRepositories(tester);
      await iFollowByItsAddressInstead(tester);
      await followingARepositoryByHandIsOpen(tester);
    });
    testWidgets('''a token the forge accepts connects it, and is kept here''', (tester) async {
      await bddSetUp(tester);
      await theForgeReachesAsAnAdminAndWithoutAdminRights(tester, 'acme/api', 'acme/web');
      await iChooseTheCommand(tester, 'A project from a repository you have');
      await iConnectTheForgeWithTheToken(tester, 'ghp_accepted');
      await itSays(tester, 'GitHub');
      await itSays(tester, 'login alice');
      await theKeychainHereKeepsTheToken(tester, 'ghp_accepted');
      await itDoesNotSay(tester, 'ghp_accepted');
    });
    testWidgets('''a stored token the forge refuses is said in its words''', (tester) async {
      await bddSetUp(tester);
      await iChooseTheCommand(tester, 'A project from a repository you have');
      await iConnectTheForgeWithTheToken(tester, 'ghp_wrong');
      await itSays(tester, 'GitHub does not accept this token');
      await theKeychainHereKeepsTheToken(tester, 'ghp_wrong');
      await theForgeFormTakesNoToken(tester);
    });
    testWidgets('''every repository says whether a machine can be bound from here''', (tester) async {
      await bddSetUp(tester);
      await theForgeReachesAsAnAdminAndWithoutAdminRights(tester, 'acme/api', 'acme/web');
      await iChooseTheCommand(tester, 'A project from a repository you have');
      await iConnectTheForgeWithTheToken(tester, 'ghp_accepted');
      await theForgesRepositorySays(tester, 'acme/api', 'can push');
      await theForgesRepositorySays(tester, 'acme/web', 'can push');
    });
    testWidgets('''a repository with no project.yml is said to be no Porelo project, and nothing is offered for it''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theForgeReachesAsAnAdminAndWithoutAdminRights(tester, 'acme/api', 'acme/web');
      await iChooseTheCommand(tester, 'A project from a repository you have');
      await iConnectTheForgeWithTheToken(tester, 'ghp_accepted');
      await iLookAtTheForgesRepository(tester, 'acme/api');
      await theForgesRepositorySays(tester, 'acme/api', 'no project.yml yet');
      await bindingIsNotOfferedFor(tester, 'acme/api');
    });
    testWidgets('''a project the token may bind is offered to be bound, saying what that does''', (tester) async {
      await bddSetUp(tester);
      await theForgeReachesAsAnAdminAndWithoutAdminRights(tester, 'acme/api', 'acme/web');
      await hasAProjectyml(tester, 'acme/api');
      await iChooseTheCommand(tester, 'A project from a repository you have');
      await iConnectTheForgeWithTheToken(tester, 'ghp_accepted');
      await iUseAsAProject(tester, 'acme/api');
      await itSays(tester, 'token in its vault');
    });
    testWidgets('''a repository with a project.yml says so on its line, and is used as a project from there''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theForgeReachesAsAnAdminAndWithoutAdminRights(tester, 'acme/api', 'acme/web');
      await hasAProjectyml(tester, 'acme/api');
      await hasAProjectyml(tester, 'acme/web');
      await iChooseTheCommand(tester, 'A project from a repository you have');
      await iConnectTheForgeWithTheToken(tester, 'ghp_accepted');
      await theForgesRepositorySays(tester, 'acme/api', 'has a project.yml');
      await theForgesRepositorySays(tester, 'acme/web', 'has a project.yml');
      await iUseAsAProject(tester, 'acme/api');
      await bindingTheMachineIsOffered(tester);
    });
    testWidgets('''a kept token is said to be used while it is tried, not offered as a field to type into''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await iGoToTheWork(tester);
      await theForgeReachesAsAnAdminAndWithoutAdminRights(tester, 'acme/api', 'acme/web');
      await theKeychainHereKeepsTheTokenForTheForge(tester, 'ghp_accepted');
      await theForgeAnswersOnlyWhenTold(tester);
      await iPickAProjectFromOneOfMyRepositories(tester);
      await itSays(tester, 'token chosen explicitly');
      await noTokenIsAskedFor(tester);
      await theForgeAnswers(tester);
      await itSays(tester, 'GitHub');
      await itSays(tester, 'login alice');
    });
    testWidgets('''the list narrows to what is searched for''', (tester) async {
      await bddSetUp(tester);
      await theForgeReachesAsAnAdminAndWithoutAdminRights(tester, 'acme/api', 'acme/web');
      await iChooseTheCommand(tester, 'A project from a repository you have');
      await iConnectTheForgeWithTheToken(tester, 'ghp_accepted');
      await iSearchTheRepositoriesFor(tester, 'web');
      await theForgesRepositoryIsListed(tester, 'acme/web');
      await theForgesRepositoryIsNotListed(tester, 'acme/api');
    });
    testWidgets('''a repository says whether it is a project already''', (tester) async {
      await bddSetUp(tester);
      await theForgeReachesAsAnAdminAndWithoutAdminRights(tester, 'acme/api', 'acme/web');
      await hasAProjectyml(tester, 'acme/api');
      await iChooseTheCommand(tester, 'A project from a repository you have');
      await iConnectTheForgeWithTheToken(tester, 'ghp_accepted');
      await iLookAtTheForgesRepository(tester, 'acme/api');
      await iLookAtTheForgesRepository(tester, 'acme/web');
      await theForgesRepositorySays(tester, 'acme/api', 'has a project.yml');
      await theForgesRepositorySays(tester, 'acme/web', 'no project.yml yet');
    });
    testWidgets('''a kept token connects without typing, and forgetting it forgets it here''', (tester) async {
      await bddSetUp(tester);
      await theForgeReachesAsAnAdminAndWithoutAdminRights(tester, 'acme/api', 'acme/web');
      await theKeychainHereKeepsTheTokenForTheForge(tester, 'ghp_accepted');
      await iChooseTheCommand(tester, 'A project from a repository you have');
      await itSays(tester, 'GitHub');
      await itSays(tester, 'login alice');
      await iForgetTheTokenHere(tester);
      await theKeychainHereKeepsNoToken(tester);
    });
    testWidgets('''a machine uses its vault token and follows pinned to the person''', (tester) async {
      await bddSetUp(tester);
      await theForgeReachesAsAnAdminAndWithoutAdminRights(tester, 'acme/api', 'acme/web');
      await holdsTheProjectWithTheWorkRepositoryAt(
        tester,
        'acme/api',
        'api',
        'backend',
        'git@github.com:acme/backend.git',
      );
      await iChooseTheCommand(tester, 'A project from a repository you have');
      await iConnectTheForgeWithTheToken(tester, 'ghp_accepted');
      await iBindTheMachineTo(tester, 'acme/api');
      await noDeployKeyCallsWereMade(tester);
      await theMachineFollowedPinnedToThePersonsKey(tester, 'api');
      await itSays(tester, 'accepts changes to the project signed with your key');
      await theMachineNeverSawTheForgesToken(tester);
    });
    testWidgets('''a follow the machine refuses ends the binding and says why''', (tester) async {
      await bddSetUp(tester);
      await theForgeReachesAsAnAdminAndWithoutAdminRights(tester, 'acme/api', 'acme/web');
      await holdsTheProjectWithTheWorkRepositoryAt(
        tester,
        'acme/api',
        'api',
        'backend',
        'git@github.com:acme/backend.git',
      );
      await theNextFollowIsRefusedAs(tester, 'NOT_SIGNED_BY_PIN');
      await iChooseTheCommand(tester, 'A project from a repository you have');
      await iConnectTheForgeWithTheToken(tester, 'ghp_accepted');
      await iBindTheMachineTo(tester, 'acme/api');
      await itSays(tester, 'did not follow api: NOT_SIGNED_BY_PIN. Nothing of it is on');
      await itDoesNotSay(tester, 'follows api');
      await theForgeHoldsNoKeyAt(tester, 'acme/backend');
    });
    testWidgets('''a machine is pinned to every signing key the forge lists for the person, asked for none''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theForgeReachesAsAnAdminAndWithoutAdminRights(tester, 'acme/api', 'acme/web');
      await holdsTheProjectWithTheWorkRepositoryAt(
        tester,
        'acme/api',
        'api',
        'backend',
        'git@github.com:acme/backend.git',
      );
      await theForgeListsMySigningKeysAnd(tester, 'Laptop', 'Desktop');
      await iChooseTheCommand(tester, 'A project from a repository you have');
      await iConnectTheForgeWithTheToken(tester, 'ghp_accepted');
      await iBindTheMachineTo(tester, 'acme/api');
      await theMachineFollowedPinnedToEverySigningKeyAtTheForge(tester, 'api');
      await itSays(tester, 'accepts changes to the project signed with any of your signing keys at GitHub');
    });
    testWidgets('''a machine that never met the forge's host trusts the key the forge publishes, and is bound''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theForgeReachesAsAnAdminAndWithoutAdminRights(tester, 'acme/api', 'acme/web');
      await holdsTheProjectWithTheWorkRepositoryAt(
        tester,
        'acme/api',
        'api',
        'backend',
        'git@github.com:acme/backend.git',
      );
      await theMachineHasNeverMetTheHost(tester, 'github.com');
      await iChooseTheCommand(tester, 'A project from a repository you have');
      await iConnectTheForgeWithTheToken(tester, 'ghp_accepted');
      await iBindTheMachineTo(tester, 'acme/api');
      await itSays(tester, 'has never met github.com');
      await itSays(tester, 'GitHub publishes this key');
      await iPress(tester, 'Trust GitHub’s published key and go on');
      await theMachineTrustsForAndNothingElse(
        tester,
        'SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU',
        'github.com',
      );
      await theMachineFollowedPinnedToThePersonsKey(tester, 'api');
      await itSays(tester, 'accepts changes to the project signed with your key');
    });
    testWidgets('''a machine is cleared in one step and its signer is removed without deploy keys''', (tester) async {
      await bddSetUp(tester);
      await theForgeReachesAsAnAdminAndWithoutAdminRights(tester, 'acme/api', 'acme/web');
      await holdsTheProjectWithTheWorkRepositoryAt(
        tester,
        'acme/api',
        'api',
        'backend',
        'git@github.com:acme/backend.git',
      );
      await iChooseTheCommand(tester, 'A project from a repository you have');
      await iConnectTheForgeWithTheToken(tester, 'ghp_accepted');
      await iBindTheMachineTo(tester, 'acme/api');
      await iCloseTheBindingAndTheRepositories(tester);
      await iChooseTheCommand(tester, 'Clear this machine of everything Porelo put there…');
      await itSays(tester, 'This goes, on');
      await iPress(tester, 'Clear it');
      await theMachineWasClearedAfterADryRun(tester, 'everything');
      await theForgeHoldsNoKeyOfTheMachineAtOr(tester, 'acme/api', 'acme/backend');
      await noDeployKeyCallsWereMade(tester);
    });
    testWidgets('''a work repository that is a project of its own is said so at the binding''', (tester) async {
      await bddSetUp(tester);
      await theForgeReachesAsAnAdminAndWithoutAdminRights(tester, 'acme/api', 'acme/web');
      await holdsTheProjectWithTheWorkRepositoryAt(
        tester,
        'acme/api',
        'api',
        'backend',
        'git@github.com:acme/backend.git',
      );
      await isAProjectOfItsOwn(tester, 'acme/backend');
      await iChooseTheCommand(tester, 'A project from a repository you have');
      await iConnectTheForgeWithTheToken(tester, 'ghp_accepted');
      await iBindTheMachineTo(tester, 'acme/api');
      await itSays(tester, 'acme/backend holds a project.yml of its own');
    });
    testWidgets('''removing a machine removes its signer without deploy keys''', (tester) async {
      await bddSetUp(tester);
      await theForgeReachesAsAnAdminAndWithoutAdminRights(tester, 'acme/api', 'acme/web');
      await holdsTheProjectWithTheWorkRepositoryAt(
        tester,
        'acme/api',
        'api',
        'backend',
        'git@github.com:acme/backend.git',
      );
      await iChooseTheCommand(tester, 'A project from a repository you have');
      await iConnectTheForgeWithTheToken(tester, 'ghp_accepted');
      await iBindTheMachineTo(tester, 'acme/api');
      await iRemoveTheMachine(tester);
      await theForgeHoldsNoKeyOfTheMachineAtOr(tester, 'acme/api', 'acme/backend');
      await itSays(tester, 'no longer follows api');
      await noDeployKeyCallsWereMade(tester);
    });
    testWidgets('''a machine that pinned another key than the person's says so''', (tester) async {
      await bddSetUp(tester);
      await theForgeReachesAsAnAdminAndWithoutAdminRights(tester, 'acme/api', 'acme/web');
      await holdsTheProjectWithTheWorkRepositoryAt(
        tester,
        'acme/api',
        'api',
        'backend',
        'git@github.com:acme/backend.git',
      );
      await theMachinePinsWhenItFollows(tester, 'SHA256:somebody-else');
      await iChooseTheCommand(tester, 'A project from a repository you have');
      await iConnectTheForgeWithTheToken(tester, 'ghp_accepted');
      await iBindTheMachineTo(tester, 'acme/api');
      await itSays(tester, 'which is not your key SHA256:person. Do not go on until you know why.');
    });
    testWidgets('''work is started on a machine once it is bound, the project chosen''', (tester) async {
      await bddSetUp(tester);
      await theForgeReachesAsAnAdminAndWithoutAdminRights(tester, 'acme/api', 'acme/web');
      await holdsTheProjectWithTheWorkRepositoryAt(
        tester,
        'acme/api',
        'api',
        'backend',
        'git@github.com:acme/backend.git',
      );
      await iChooseTheCommand(tester, 'A project from a repository you have');
      await iConnectTheForgeWithTheToken(tester, 'ghp_accepted');
      await iBindTheMachineTo(tester, 'acme/api');
      await itSays(tester, 'Start work in api');
      await itSays(tester, 'accepts changes to the project signed with your key');
      await theProjectIsTheOneShown(tester, 'api');
    });
    testWidgets(
      '''a configuration change waiting at a machine's gate is reviewed, merged signed here, and cleared there''',
      (tester) async {
        await bddSetUp(tester);
        await theForgeReachesAsAnAdminAndWithoutAdminRights(tester, 'acme/api', 'acme/web');
        await holdsTheProjectWithTheWorkRepositoryAt(
          tester,
          'acme/api',
          'api',
          'backend',
          'git@github.com:acme/backend.git',
        );
        await theMachinesGateHoldsTheChangeSaying(tester, 'plan', 'Add the internal mirror');
        await iChooseTheCommand(tester, 'A project from a repository you have');
        await iConnectTheForgeWithTheToken(tester, 'ghp_accepted');
        await iBindTheMachineTo(tester, 'acme/api');
        await iLookAtTheChangesWaitingAtTheMachine(tester);
        await mergingTheChangeIsNotOfferedYet(tester, 'plan');
        await iReviewTheChange(tester, 'plan');
        await itSays(tester, '+  sets: [internal-mirror]');
        await iMergeTheChangeSigned(tester, 'plan');
        await theChangeWasMergedHereSignedWith(tester, 'plan', 'SHA256:person');
        await theMachineWasToldLandedOn(tester, 'plan', 'main');
        await itSays(tester, 'pushed to main, and cleared at');
      },
    );
    testWidgets('''a merge the upstream does not hold yet is said in the machine's words, and stays listed''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theForgeReachesAsAnAdminAndWithoutAdminRights(tester, 'acme/api', 'acme/web');
      await holdsTheProjectWithTheWorkRepositoryAt(
        tester,
        'acme/api',
        'api',
        'backend',
        'git@github.com:acme/backend.git',
      );
      await theMachinesGateHoldsTheChangeSaying(tester, 'plan', 'Add the internal mirror');
      await theUpstreamDoesNotHoldWhatIsMergedYet(tester);
      await iChooseTheCommand(tester, 'A project from a repository you have');
      await iConnectTheForgeWithTheToken(tester, 'ghp_accepted');
      await iBindTheMachineTo(tester, 'acme/api');
      await iLookAtTheChangesWaitingAtTheMachine(tester);
      await iReviewTheChange(tester, 'plan');
      await iMergeTheChangeSigned(tester, 'plan');
      await itSays(tester, 'push the merge first');
      await theChangeIsStillListed(tester, 'plan');
    });
    testWidgets('''a machine that does not repeat what it pinned is not said to have pinned another key''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theForgeReachesAsAnAdminAndWithoutAdminRights(tester, 'acme/api', 'acme/web');
      await holdsTheProjectWithTheWorkRepositoryAt(
        tester,
        'acme/api',
        'api',
        'backend',
        'git@github.com:acme/backend.git',
      );
      await theMachinePinsWhenItFollows(tester, '');
      await iChooseTheCommand(tester, 'A project from a repository you have');
      await iConnectTheForgeWithTheToken(tester, 'ghp_accepted');
      await iBindTheMachineTo(tester, 'acme/api');
      await itSays(tester, 'accepts changes to the project signed with your key');
      await itDoesNotSay(tester, 'Do not go on');
    });
    testWidgets('''the forges are a place of their own, after the machines, each opened to its repositories''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theForgeReachesAsAnAdminAndWithoutAdminRights(tester, 'acme/api', 'acme/web');
      await theKeychainHereKeepsTheTokenForTheForge(tester, 'ghp_accepted');
      await theMachineFollowsTheProjectFrom(tester, 'checkout', 'git@github.com:acme/api.git');
      await theRailListsInThisOrder(tester, 'Machines, Forges, Projects');
      await iGoToTheForges(tester);
      await itSays(tester, 'Connect a forge');
      await iChooseTheForge(tester, 'GitHub');
      await theForgesRepositoryIsListed(tester, 'acme/api');
      await theRepositoryIsWorkedOnOn(tester, 'acme/api', 'this machine');
    });
    testWidgets('''a repository is worked on without a project from its card without deploy keys''', (tester) async {
      await bddSetUp(tester);
      await theForgeReachesAsAnAdminAndWithoutAdminRights(tester, 'acme/api', 'acme/web');
      await theKeychainHereKeepsTheTokenForTheForge(tester, 'ghp_accepted');
      await iGoToTheForges(tester);
      await iChooseTheForge(tester, 'GitHub');
      await iLookAtTheForgesRepository(tester, 'acme/api');
      await iChooseFromTheCardOf(tester, 'default-add', 'acme/api');
      await defaultHoldsAt(tester, 'api', 'https://github.com/acme/api.git');
      await noDeployKeyCallsWereMade(tester);
    });
  });
}
