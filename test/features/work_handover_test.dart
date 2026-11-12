// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_the_work.dart';
import './step/i_select_the_project.dart';
import './step/i_select_the_work.dart';
import './step/i_open_the_selection.dart';
import './step/it_says.dart';
import './step/i_review_what_is_waiting_at_the_gate.dart';
import './step/i_open_the_waiting_push.dart';
import './step/the_review_shows_the_file.dart';
import './step/the_review_shows.dart';
import './step/i_copy_the_diff.dart';
import './step/what_was_copied_mentions.dart';
import './step/it_does_not_say.dart';
import './step/i_forward_it_onto_the_branch.dart';
import './step/it_was_forwarded_onto.dart';
import './step/the_forward_named_the_commit_reviewed.dart';
import './step/the_status_line_mentions.dart';
import './step/the_projects_were_read_again_after_it.dart';
import './step/the_push_moves_before_it_is_forwarded.dart';
import './step/the_branch_already_holds_earlier_work.dart';
import './step/the_forge_refuses_the_push_for_its_deploy_key.dart';
import './step/no_push_went_upstream.dart';
import './step/no_ssh_key_is_declared_for_the_forge.dart';
import './step/the_forge_takes_the_key.dart';
import './step/i_try_the_key.dart';
import './step/the_key_was_tried_alone_for.dart';
import './step/nothing_was_declared.dart';
import './step/i_keep_the_key.dart';
import './step/the_key_was_kept_for_from.dart';
import './step/the_account_also_has_a_key_file_locked_by_a_passphrase.dart';
import './step/the_key_cannot_be_kept.dart';
import './step/i_open_the_terminal_for_the_refused_key.dart';
import './step/i_do_not_start_it.dart';
import './step/no_terminal_was_opened.dart';
import './step/i_press_return_on_the_branch.dart';
import './step/i_drop_the_request.dart';
import './step/nothing_was_forwarded.dart';
import './step/i_drop_the_request_saying.dart';
import './step/the_drop_gave_the_reason.dart';
import './step/the_task_the_waiting_push_came_from_is_gone.dart';
import './step/i_start_to_drop_the_request_and_cancel.dart';
import './step/nothing_was_dropped.dart';
import './step/i_open_the_command_finder.dart';
import './step/the_command_is_offered_as_unavailable.dart';
import './step/the_work_holds_unpushed_commits_and_changed_files.dart';
import './step/nobody_could_look_inside_the_work.dart';
import './step/the_work_held_unpushed_commits_when_it_stopped.dart';
import './step/the_machine_knows_no_such_task.dart';
import './step/the_project_has_the_repositories.dart';
import './step/waits_in_the_repository.dart';
import './step/it_was_reviewed_in_the_repository.dart';
import './step/it_was_forwarded_from_the_repository.dart';
import './step/the_gate_of_the_repository_cannot_be_read.dart';
import './step/the_gate_was_asked_about_no_repository.dart';
import './step/the_work_works_in_the_repository.dart';
import './step/the_machine_ranks_the_waiting_push_with_a_ci_definition_the_change_and_a_generated_file.dart';
import './step/the_review_lists_in_that_order.dart';
import './step/the_file_is_marked.dart';
import './step/the_file_is_under_what_is_almost_never_a_finding.dart';
import './step/the_machine_counts_a_crlf_to_lf_file_of_three_real_lines.dart';
import './step/i_show_the_diff_without_line_endings.dart';
import './step/the_review_was_asked_without_line_endings.dart';
import './step/the_machine_cannot_leave_line_endings_out_of_a_review.dart';
import './step/no_review_was_asked_without_line_endings.dart';
import './step/the_task_that_pushed_was_asked.dart';
import './step/the_review_says_it_was_asked.dart';
import './step/the_task_that_pushed_was_asked_nothing.dart';
import './step/the_review_says_is.dart';
import './step/the_trailer_check_reads.dart';
import './step/the_machine_names_the_commit_as_written_by_with_the_trailers_and.dart';
import './step/the_window_is_pixels_wide.dart';
import './step/the_waiting_push_names_its_author_and_the_trailers_and.dart';
import './step/the_machine_is_slow_to_answer.dart';
import './step/it_shows_that_it_is_reading.dart';
import './step/the_machine_has_answered.dart';
import './step/it_no_longer_shows_that_it_is_reading.dart';
import './step/the_machine_has_the_project_from.dart';
import './step/i_choose_the_command.dart';

void main() {
  group('''Reviewing what work pushed, and what it holds back''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await iGoToTheWork(tester);
      await iSelectTheProject(tester, 'checkout');
    }

    testWidgets('''work whose own commits are waiting for review says so on its detail''', (tester) async {
      await bddSetUp(tester);
      await iSelectTheWork(tester, 'porelo-checkout-migrate');
      await iOpenTheSelection(tester);
      await itSays(tester, 'its own work is waiting for review');
    });
    testWidgets('''work with nothing of its own waiting says that instead''', (tester) async {
      await bddSetUp(tester);
      await iSelectTheWork(tester, 'porelo-checkout-shell');
      await iOpenTheSelection(tester);
      await itSays(tester, 'nothing of its own is waiting');
    });
    testWidgets('''what a project pushed is readable file by file, without leaving the interface''', (tester) async {
      await bddSetUp(tester);
      await iReviewWhatIsWaitingAtTheGate(tester);
      await iOpenTheWaitingPush(tester);
      await theReviewShowsTheFile(tester, 'lib/money.dart');
      await theReviewShows(tester, '(value * 100).round()');
    });
    testWidgets('''a waiting push can be fetched into the person's own clone''', (tester) async {
      await bddSetUp(tester);
      await iReviewWhatIsWaitingAtTheGate(tester);
      await iOpenTheWaitingPush(tester);
      await itSays(
        tester,
        'git fetch ssh://porelo@build-01/srv/checkout/.porelo/mirror refs/porelo/incoming/migrate:refs/remotes/porelo/migrate',
      );
      await itSays(tester, 'safe mode');
    });
    testWidgets('''the diff leaves the interface in one action, for reading somewhere else''', (tester) async {
      await bddSetUp(tester);
      await iReviewWhatIsWaitingAtTheGate(tester);
      await iOpenTheWaitingPush(tester);
      await iCopyTheDiff(tester);
      await whatWasCopiedMentions(tester, 'lib/money.dart');
      await whatWasCopiedMentions(tester, '(value * 100).round()');
    });
    testWidgets('''a waiting push is listed by its short commit, and forwarded by its full one''', (tester) async {
      await bddSetUp(tester);
      await iReviewWhatIsWaitingAtTheGate(tester);
      await itSays(tester, '9a3c1f2');
      await itDoesNotSay(tester, '9a3c1f2e4b5d6a7c8e9f0a1b2c3d4e5f6a7b8c9d');
    });
    testWidgets('''forwarding names the branch rather than guessing one''', (tester) async {
      await bddSetUp(tester);
      await iReviewWhatIsWaitingAtTheGate(tester);
      await iOpenTheWaitingPush(tester);
      await iForwardItOntoTheBranch(tester, 'fix-rounding');
      await itWasForwardedOnto(tester, 'fix-rounding');
      await theForwardNamedTheCommitReviewed(tester, '9a3c1f2e4b5d6a7c8e9f0a1b2c3d4e5f6a7b8c9d');
      await theStatusLineMentions(tester, 'was forwarded to fix-rounding');
      await theProjectsWereReadAgainAfterIt(tester);
    });
    testWidgets('''a push that moved since it was reviewed is not forwarded, and that is said''', (tester) async {
      await bddSetUp(tester);
      await iReviewWhatIsWaitingAtTheGate(tester);
      await iOpenTheWaitingPush(tester);
      await thePushMovesBeforeItIsForwarded(tester);
      await iForwardItOntoTheBranch(tester, 'fix-rounding');
      await itSays(tester, 'moved since you reviewed it: you read 9a3c1f2, and it holds b7e21d4 now');
      await itSays(tester, 'Nothing was forwarded');
    });
    testWidgets('''a branch that already holds earlier work is not forwarded onto, and another is named''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await iReviewWhatIsWaitingAtTheGate(tester);
      await iOpenTheWaitingPush(tester);
      await theBranchAlreadyHoldsEarlierWork(tester, 'fix-rounding');
      await iForwardItOntoTheBranch(tester, 'fix-rounding');
      await itSays(tester, 'fix-rounding already holds 4d2e9a1, from earlier work');
      await itSays(tester, 'Nothing was forwarded');
      await itSays(tester, 'onto another branch, such as fix-rounding-2');
    });
    testWidgets('''a forward refused for its key says which key, and not git's line''', (tester) async {
      await bddSetUp(tester);
      await iReviewWhatIsWaitingAtTheGate(tester);
      await iOpenTheWaitingPush(tester);
      await theForgeRefusesThePushForItsDeployKey(tester);
      await iForwardItOntoTheBranch(tester, 'fix-rounding');
      await itSays(tester, 'Nothing was forwarded');
      await itSays(tester, 'The forge knows the key as a deploy key');
      await itSays(tester, 'Key used: SHA256:deployKeyOfTheRepository, held by the ssh-agent.');
      await itSays(tester, 'SHA256:personalKeyOfThePerson');
      await itSays(tester, '/home/alice/.ssh/id_rsa');
      await itDoesNotSay(tester, 'exit code');
      await itDoesNotSay(tester, '--git-dir');
      await noPushWentUpstream(tester);
    });
    testWidgets('''a forward with no key declared for its address says so''', (tester) async {
      await bddSetUp(tester);
      await iReviewWhatIsWaitingAtTheGate(tester);
      await iOpenTheWaitingPush(tester);
      await noSshKeyIsDeclaredForTheForge(tester);
      await iForwardItOntoTheBranch(tester, 'fix-rounding');
      await itSays(tester, 'No ssh key is declared for ssh://git@github.com/acme/money.git');
      await noPushWentUpstream(tester);
    });
    testWidgets('''a key tried alone is answered, and nothing is pushed or kept''', (tester) async {
      await bddSetUp(tester);
      await iReviewWhatIsWaitingAtTheGate(tester);
      await iOpenTheWaitingPush(tester);
      await theForgeRefusesThePushForItsDeployKey(tester);
      await theForgeTakesTheKey(tester, 'SHA256:personalKeyOfThePerson');
      await iForwardItOntoTheBranch(tester, 'fix-rounding');
      await iTryTheKey(tester, 'SHA256:personalKeyOfThePerson');
      await itSays(tester, 'The forge would take the push with this key. Nothing was pushed.');
      await theKeyWasTriedAloneFor(
        tester,
        'SHA256:personalKeyOfThePerson',
        'refs/porelo/incoming/migrate:refs/heads/fix-rounding',
      );
      await noPushWentUpstream(tester);
      await nothingWasDeclared(tester);
    });
    testWidgets('''keeping a key keeps it for that address alone, and forwards the reviewed commit again''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await iReviewWhatIsWaitingAtTheGate(tester);
      await iOpenTheWaitingPush(tester);
      await theForgeRefusesThePushForItsDeployKey(tester);
      await iForwardItOntoTheBranch(tester, 'fix-rounding');
      await iKeepTheKey(tester, 'SHA256:personalKeyOfThePerson');
      await theKeyWasKeptForFrom(
        tester,
        'SHA256:personalKeyOfThePerson',
        'ssh://git@github.com/acme/money.git',
        'AGENT',
      );
      await itWasForwardedOnto(tester, 'fix-rounding');
      await theForwardNamedTheCommitReviewed(tester, '9a3c1f2e4b5d6a7c8e9f0a1b2c3d4e5f6a7b8c9d');
    });
    testWidgets('''a key kept from a file is named by its path''', (tester) async {
      await bddSetUp(tester);
      await iReviewWhatIsWaitingAtTheGate(tester);
      await iOpenTheWaitingPush(tester);
      await theForgeRefusesThePushForItsDeployKey(tester);
      await iForwardItOntoTheBranch(tester, 'fix-rounding');
      await iKeepTheKey(tester, '/home/alice/.ssh/id_rsa');
      await theKeyWasKeptForFrom(tester, '/home/alice/.ssh/id_rsa', 'ssh://git@github.com/acme/money.git', 'FILE');
    });
    testWidgets('''a forward refused for another reason after a refused key leaves no stale way through''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await iReviewWhatIsWaitingAtTheGate(tester);
      await iOpenTheWaitingPush(tester);
      await theForgeRefusesThePushForItsDeployKey(tester);
      await iForwardItOntoTheBranch(tester, 'fix-rounding');
      await theBranchAlreadyHoldsEarlierWork(tester, 'other-branch');
      await iForwardItOntoTheBranch(tester, 'other-branch');
      await itSays(tester, 'other-branch already holds 4d2e9a1');
      await itDoesNotSay(tester, 'Choose the key to forward fix-rounding');
    });
    testWidgets('''a key file the machine cannot sign with is not offered to keep''', (tester) async {
      await bddSetUp(tester);
      await iReviewWhatIsWaitingAtTheGate(tester);
      await iOpenTheWaitingPush(tester);
      await theForgeRefusesThePushForItsDeployKey(tester);
      await theAccountAlsoHasAKeyFileLockedByAPassphrase(tester, '/home/alice/.ssh/id_locked');
      await iForwardItOntoTheBranch(tester, 'fix-rounding');
      await theKeyCannotBeKept(tester, '/home/alice/.ssh/id_locked');
    });
    testWidgets('''what only a terminal can do is shown ready, and nothing runs until it is started''', (tester) async {
      await bddSetUp(tester);
      await iReviewWhatIsWaitingAtTheGate(tester);
      await iOpenTheWaitingPush(tester);
      await theForgeRefusesThePushForItsDeployKey(tester);
      await iForwardItOntoTheBranch(tester, 'fix-rounding');
      await iOpenTheTerminalForTheRefusedKey(tester);
      await itSays(tester, 'porelo credentials keys');
      await iDoNotStartIt(tester);
      await noTerminalWasOpened(tester);
    });
    testWidgets('''an empty branch is not an answer, however it is given''', (tester) async {
      await bddSetUp(tester);
      await iReviewWhatIsWaitingAtTheGate(tester);
      await iOpenTheWaitingPush(tester);
      await iPressReturnOnTheBranch(tester, '  ');
      await noPushWentUpstream(tester);
    });
    testWidgets('''dropping the request leaves the work in the mirror''', (tester) async {
      await bddSetUp(tester);
      await iReviewWhatIsWaitingAtTheGate(tester);
      await iOpenTheWaitingPush(tester);
      await iDropTheRequest(tester);
      await theStatusLineMentions(tester, 'still in the mirror');
      await theStatusLineMentions(tester, 'Its task was told.');
      await nothingWasForwarded(tester);
    });
    testWidgets('''dropping the request can say why, and its task is told those words''', (tester) async {
      await bddSetUp(tester);
      await iReviewWhatIsWaitingAtTheGate(tester);
      await iOpenTheWaitingPush(tester);
      await iDropTheRequestSaying(tester, 'the rounding is still wrong');
      await theDropGaveTheReason(tester, 'the rounding is still wrong');
      await theStatusLineMentions(tester, 'Its task was told, with your words.');
    });
    testWidgets('''a push whose task is gone is dropped, and it says nobody was told''', (tester) async {
      await bddSetUp(tester);
      await theTaskTheWaitingPushCameFromIsGone(tester);
      await iReviewWhatIsWaitingAtTheGate(tester);
      await iOpenTheWaitingPush(tester);
      await iDropTheRequest(tester);
      await theStatusLineMentions(tester, 'nobody was told');
    });
    testWidgets('''cancelling the drop keeps the request''', (tester) async {
      await bddSetUp(tester);
      await iReviewWhatIsWaitingAtTheGate(tester);
      await iOpenTheWaitingPush(tester);
      await iStartToDropTheRequestAndCancel(tester);
      await nothingWasDropped(tester);
    });
    testWidgets('''a project with no file recorded offers no gate, and names the reason''', (tester) async {
      await bddSetUp(tester);
      await iSelectTheProject(tester, 'unrecorded');
      await iOpenTheCommandFinder(tester);
      await theCommandIsOfferedAsUnavailable(tester, 'Review what is waiting at the gate');
    });
    testWidgets('''the gate says what it does not see, rather than reading as a wall''', (tester) async {
      await bddSetUp(tester);
      await iReviewWhatIsWaitingAtTheGate(tester);
      await itSays(tester, 'Work can also be pushed straight upstream by hand');
      await itSays(tester, 'per clone, on the machine you push from');
    });
    testWidgets('''where somebody asks what an agent was told, the answer is not here''', (tester) async {
      await bddSetUp(tester);
      await iSelectTheWork(tester, 'porelo-checkout-shell');
      await iOpenTheSelection(tester);
      await itSays(tester, 'in the repository — nothing here has a view of them');
    });
    testWidgets('''what a running task holds that never reached the gate is on its detail''', (tester) async {
      await bddSetUp(tester);
      await theWorkHoldsUnpushedCommitsAndChangedFiles(tester, 2, 3);
      await iSelectTheWork(tester, 'porelo-checkout-shell');
      await iOpenTheSelection(tester);
      await itSays(tester, 'holds 2 unpushed commits and 3 changed files');
    });
    testWidgets('''holding nothing is said as holding nothing''', (tester) async {
      await bddSetUp(tester);
      await theWorkHoldsUnpushedCommitsAndChangedFiles(tester, 0, 0);
      await iSelectTheWork(tester, 'porelo-checkout-shell');
      await iOpenTheSelection(tester);
      await itSays(tester, 'holds nothing that never reached the gate');
    });
    testWidgets('''a task nobody could look inside says that, not that it holds nothing''', (tester) async {
      await bddSetUp(tester);
      await nobodyCouldLookInsideTheWork(tester);
      await iSelectTheWork(tester, 'porelo-checkout-shell');
      await iOpenTheSelection(tester);
      await itSays(tester, 'nothing recorded what it held');
      await itSays(tester, 'killed, rebooted, or stopped by an older Porelo');
    });
    testWidgets('''a stopped task says what it held when it stopped, and when that was''', (tester) async {
      await bddSetUp(tester);
      await theWorkHeldUnpushedCommitsWhenItStopped(tester, 4);
      await iSelectTheWork(tester, 'porelo-checkout-shell');
      await iOpenTheSelection(tester);
      await itSays(tester, 'held 4 unpushed commits when it stopped');
      await itSays(tester, 'minutes ago');
    });
    testWidgets('''a name the machine does not know is refused rather than read as unreadable''', (tester) async {
      await bddSetUp(tester);
      await theMachineKnowsNoSuchTask(tester);
      await iSelectTheWork(tester, 'porelo-checkout-shell');
      await iOpenTheSelection(tester);
      await itSays(tester, 'does not know a task called');
    });
    testWidgets('''what waits in every repository is shown, and each push is decided where it waits''', (tester) async {
      await bddSetUp(tester);
      await theProjectHasTheRepositories(tester, 'checkout', 'checkout, payments-api');
      await waitsInTheRepository(tester, 'Retry a declined card once', 'payments-api');
      await iReviewWhatIsWaitingAtTheGate(tester);
      await itSays(tester, 'Round to the nearest penny, not away from zero');
      await itSays(tester, 'Retry a declined card once');
      await itSays(tester, 'in payments-api');
      await iOpenTheWaitingPush(tester, 'Retry a declined card once');
      await itWasReviewedInTheRepository(tester, 'payments-api');
      await iForwardItOntoTheBranch(tester, 'retry-once');
      await itWasForwardedFromTheRepository(tester, 'payments-api');
    });
    testWidgets('''a repository whose gate cannot be read is named, and does not hide the others''', (tester) async {
      await bddSetUp(tester);
      await theProjectHasTheRepositories(tester, 'checkout', 'checkout, payments-api');
      await theGateOfTheRepositoryCannotBeRead(tester, 'payments-api');
      await iReviewWhatIsWaitingAtTheGate(tester);
      await itSays(tester, 'Round to the nearest penny, not away from zero');
      await itSays(tester, 'payments-api could not be read');
    });
    testWidgets('''a machine that names no repositories is asked about none''', (tester) async {
      await bddSetUp(tester);
      await iReviewWhatIsWaitingAtTheGate(tester);
      await iOpenTheWaitingPush(tester);
      await iForwardItOntoTheBranch(tester, 'fix-rounding');
      await theGateWasAskedAboutNoRepository(tester);
    });
    testWidgets('''work names the repository it works in on its detail''', (tester) async {
      await bddSetUp(tester);
      await theProjectHasTheRepositories(tester, 'checkout', 'checkout, payments-api');
      await theWorkWorksInTheRepository(tester, 'porelo-checkout-migrate', 'payments-api');
      await iSelectTheWork(tester, 'porelo-checkout-migrate');
      await iOpenTheSelection(tester);
      await itSays(tester, 'payments-api');
    });
    testWidgets('''a push is reviewed in the order that matters, dangerous by kind first and volume last''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theMachineRanksTheWaitingPushWithACiDefinitionTheChangeAndAGeneratedFile(tester);
      await iReviewWhatIsWaitingAtTheGate(tester);
      await iOpenTheWaitingPush(tester);
      await theReviewListsInThatOrder(tester, '.github/workflows/ci.yml, lib/money.dart, lib/money.g.dart');
      await theFileIsMarked(tester, '.github/workflows/ci.yml', 'dangerous by kind');
      await itSays(tester, 'a CI definition, which runs with the credentials of CI');
      await theFileIsUnderWhatIsAlmostNeverAFinding(tester, 'lib/money.g.dart');
      await itSays(tester, 'detects nothing: no file here is judged safe or injected');
    });
    testWidgets('''a change mostly of line endings says so, with the real count beside the raw one''', (tester) async {
      await bddSetUp(tester);
      await theMachineCountsACrlfToLfFileOfThreeRealLines(tester, 'lib/legacy.dart');
      await iReviewWhatIsWaitingAtTheGate(tester);
      await iOpenTheWaitingPush(tester);
      await itSays(tester, 'Mostly line endings: +1 −2 without them, +1042 −1043 with them.');
      await itSays(tester, 'The diff below holds every such line');
    });
    testWidgets('''a change that is not of line endings reads as before''', (tester) async {
      await bddSetUp(tester);
      await theMachineRanksTheWaitingPushWithACiDefinitionTheChangeAndAGeneratedFile(tester);
      await iReviewWhatIsWaitingAtTheGate(tester);
      await iOpenTheWaitingPush(tester);
      await itDoesNotSay(tester, 'line endings');
    });
    testWidgets('''the diff can be read without line endings, and says it leaves them out''', (tester) async {
      await bddSetUp(tester);
      await theMachineCountsACrlfToLfFileOfThreeRealLines(tester, 'lib/legacy.dart');
      await iReviewWhatIsWaitingAtTheGate(tester);
      await iOpenTheWaitingPush(tester);
      await iShowTheDiffWithoutLineEndings(tester);
      await theReviewWasAskedWithoutLineEndings(tester);
      await itSays(tester, 'The diff below leaves out what changed at line ends');
    });
    testWidgets('''a machine that cannot leave line endings out is never asked to, and says the diff holds them''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theMachineCountsACrlfToLfFileOfThreeRealLines(tester, 'lib/legacy.dart');
      await theMachineCannotLeaveLineEndingsOutOfAReview(tester);
      await iReviewWhatIsWaitingAtTheGate(tester);
      await iOpenTheWaitingPush(tester);
      await itSays(tester, 'this machine cannot leave them out');
      await noReviewWasAskedWithoutLineEndings(tester);
    });
    testWidgets('''what the task was asked is shown apart from what it touched''', (tester) async {
      await bddSetUp(tester);
      await theMachineRanksTheWaitingPushWithACiDefinitionTheChangeAndAGeneratedFile(tester);
      await theTaskThatPushedWasAsked(tester, 'Round money to the nearest penny');
      await iReviewWhatIsWaitingAtTheGate(tester);
      await iOpenTheWaitingPush(tester);
      await theReviewSaysItWasAsked(tester, 'Round money to the nearest penny');
      await itDoesNotSay(tester, 'not asked for');
    });
    testWidgets('''a task started without an instruction is said to have had none''', (tester) async {
      await bddSetUp(tester);
      await theMachineRanksTheWaitingPushWithACiDefinitionTheChangeAndAGeneratedFile(tester);
      await theTaskThatPushedWasAskedNothing(tester);
      await iReviewWhatIsWaitingAtTheGate(tester);
      await iOpenTheWaitingPush(tester);
      await itSays(tester, 'It was started without an instruction.');
    });
    testWidgets('''a task gone from the machine is said to leave what it was asked unknown''', (tester) async {
      await bddSetUp(tester);
      await theMachineRanksTheWaitingPushWithACiDefinitionTheChangeAndAGeneratedFile(tester);
      await iReviewWhatIsWaitingAtTheGate(tester);
      await iOpenTheWaitingPush(tester);
      await itSays(tester, 'what it was asked is not known here');
    });
    testWidgets('''the review names the commit, and says who wrote it and its trailer are not reported''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await iReviewWhatIsWaitingAtTheGate(tester);
      await iOpenTheWaitingPush(tester);
      await theReviewSaysIs(tester, 'Commit', '9a3c1f2e4b5d6a7c8e9f0a1b2c3d4e5f6a7b8c9d');
      await theReviewSaysIs(tester, 'Author', 'not reported by the machine');
      await theReviewSaysIs(tester, 'Committer', 'not reported by the machine');
      await theReviewSaysIs(tester, 'Trailer', 'not reported by the machine');
      await theReviewSaysIs(tester, 'Trailer', 'cannot be checked here');
      await theTrailerCheckReads(tester, 'unknown');
    });
    testWidgets('''a commit that names a co-author is shown as wrong, never as checked''', (tester) async {
      await bddSetUp(tester);
      await theMachineNamesTheCommitAsWrittenByWithTheTrailersAnd(
        tester,
        'An Agent',
        'Assisted-by: Claude Code claude-opus-5-5',
        'Co-Authored-By: Claude',
      );
      await iReviewWhatIsWaitingAtTheGate(tester);
      await iOpenTheWaitingPush(tester);
      await theReviewSaysIs(tester, 'Author', 'An Agent');
      await theReviewSaysIs(tester, 'Trailer', 'Co-Authored-By: Claude');
      await theTrailerCheckReads(tester, 'wrong');
    });
    testWidgets('''a commit that names two agents is shown as wrong''', (tester) async {
      await bddSetUp(tester);
      await theMachineNamesTheCommitAsWrittenByWithTheTrailersAnd(
        tester,
        'An Agent',
        'Assisted-by: Claude Code claude-opus-5-5',
        'Assisted-by: Codex',
      );
      await iReviewWhatIsWaitingAtTheGate(tester);
      await iOpenTheWaitingPush(tester);
      await theTrailerCheckReads(tester, 'wrong');
    });
    testWidgets('''a commit with one Assisted-by and no co-author is shown as checked''', (tester) async {
      await bddSetUp(tester);
      await theMachineNamesTheCommitAsWrittenByWithTheTrailersAnd(
        tester,
        'An Agent',
        'Assisted-by: Claude Code claude-opus-5-5',
        'Signed-off-by: A Person',
      );
      await iReviewWhatIsWaitingAtTheGate(tester);
      await iOpenTheWaitingPush(tester);
      await theReviewSaysIs(tester, 'Committer', 'A Person');
      await theTrailerCheckReads(tester, 'passed');
    });
    testWidgets('''on a narrow window who made the commit and its trailer stay whole''', (tester) async {
      await bddSetUp(tester);
      await theMachineNamesTheCommitAsWrittenByWithTheTrailersAnd(
        tester,
        'An Agent With A Rather Long Name From The Build Farm',
        'Assisted-by: Claude Code claude-opus-5-5 running in the container porelo-checkout-migrate-1',
        'Co-Authored-By: Claude',
      );
      await theWindowIsPixelsWide(tester, 390);
      await iReviewWhatIsWaitingAtTheGate(tester);
      await iOpenTheWaitingPush(tester);
      await theReviewSaysIs(
        tester,
        'Author',
        'An Agent With A Rather Long Name From The Build Farm <agent@example.org>',
      );
      await theReviewSaysIs(
        tester,
        'Trailer',
        'Assisted-by: Claude Code claude-opus-5-5 running in the container porelo-checkout-migrate-1',
      );
      await theTrailerCheckReads(tester, 'wrong');
    });
    testWidgets('''the makers named on the waiting push are checked where the review lists none''', (tester) async {
      await bddSetUp(tester);
      await theWaitingPushNamesItsAuthorAndTheTrailersAnd(
        tester,
        'An Agent',
        'Assisted-by: Claude Code claude-opus-5-5',
        'Co-Authored-By: Claude',
      );
      await iReviewWhatIsWaitingAtTheGate(tester);
      await iOpenTheWaitingPush(tester);
      await theReviewSaysIs(tester, 'Author', 'An Agent');
      await theReviewSaysIs(tester, 'Committer', 'not reported by the machine');
      await theTrailerCheckReads(tester, 'wrong');
    });
    testWidgets('''a machine that does not rank the review shows it as before''', (tester) async {
      await bddSetUp(tester);
      await iReviewWhatIsWaitingAtTheGate(tester);
      await iOpenTheWaitingPush(tester);
      await theReviewShowsTheFile(tester, 'lib/money.dart');
      await itDoesNotSay(tester, 'What the task was asked');
    });
    testWidgets('''while the machine is asked, the gate says what it is reading''', (tester) async {
      await bddSetUp(tester);
      await theMachineIsSlowToAnswer(tester);
      await iReviewWhatIsWaitingAtTheGate(tester);
      await itShowsThatItIsReading(tester, 'the gate of checkout');
      await itDoesNotSay(tester, 'Nothing is waiting');
      await theMachineHasAnswered(tester);
      await itNoLongerShowsThatItIsReading(tester);
      await itSays(tester, '9a3c1f2');
    });
    testWidgets('''a push being opened says what is read, then what it changes''', (tester) async {
      await bddSetUp(tester);
      await iReviewWhatIsWaitingAtTheGate(tester);
      await theMachineIsSlowToAnswer(tester);
      await iOpenTheWaitingPush(tester);
      await itShowsThatItIsReading(tester, 'what this push changes');
      await theMachineHasAnswered(tester);
      await itNoLongerShowsThatItIsReading(tester);
      await theReviewShowsTheFile(tester, 'lib/money.dart');
    });
    testWidgets('''another project's waiting pushes are not shown while its own gate is read''', (tester) async {
      await bddSetUp(tester);
      await iReviewWhatIsWaitingAtTheGate(tester);
      await theMachineHasTheProjectFrom(tester, 'api', 'git@github.com:acme/api.git');
      await iSelectTheProject(tester, 'api');
      await theMachineIsSlowToAnswer(tester);
      await iChooseTheCommand(tester, 'Review what is waiting at the gate');
      await itDoesNotSay(tester, '9a3c1f2');
      await itShowsThatItIsReading(tester, 'the gate of api');
      await theMachineHasAnswered(tester);
      await itNoLongerShowsThatItIsReading(tester);
    });
  });
}
