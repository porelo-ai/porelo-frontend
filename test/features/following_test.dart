// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_the_work.dart';
import './step/the_project_follows_its_repository_at.dart';
import './step/the_project_says.dart';
import './step/the_project_says_nothing_about_following.dart';
import './step/the_newest_commit_of_is_signed_by_the_unknown_key.dart';
import './step/i_go_to_what_needs_a_person.dart';
import './step/what_needs_a_person_names_the_project.dart';
import './step/it_says.dart';
import './step/the_count_of_what_needs_a_person_is.dart';
import './step/the_repository_of_cannot_be_reached_for_now.dart';
import './step/what_needs_a_person_does_not_name_the_project.dart';
import './step/the_repository_of_needs_a_credential_from_a_shut_store.dart';
import './step/the_project_does_not_say.dart';
import './step/the_project_is_followed_unverified.dart';
import './step/the_card_of_is_marked_unverified.dart';
import './step/the_card_of_is_not_marked_unverified.dart';
import './step/the_history_of_was_rewritten.dart';
import './step/i_press.dart';
import './step/the_machine_was_asked_to_follow_taking_the_rewritten_history.dart';

void main() {
  group('''How far following a project's repository has got, and who must act''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await iGoToTheWork(tester);
    }

    testWidgets('''a project that is followed says which commit is in force''', (tester) async {
      await bddSetUp(tester);
      await theProjectFollowsItsRepositoryAt(tester, 'checkout', '4f2a9c1e0b77');
      await theProjectSays(tester, 'checkout', 'Following, at 4f2a9c1');
    });
    testWidgets('''a project nobody follows says nothing about following''', (tester) async {
      await bddSetUp(tester);
      await theProjectSaysNothingAboutFollowing(tester, 'checkout');
    });
    testWidgets('''a commit signed by an unknown key is refused, named, and put in front of a person''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theNewestCommitOfIsSignedByTheUnknownKey(tester, 'checkout', 'SHA256:9xQeTbL1');
      await theProjectSays(tester, 'checkout', 'signed by a key this machine was never given');
      await theProjectSays(tester, 'checkout', 'still running 4f2a9c1');
      await iGoToWhatNeedsAPerson(tester);
      await whatNeedsAPersonNamesTheProject(tester, 'checkout');
      await itSays(tester, 'SHA256:9xQeTbL1');
      await theCountOfWhatNeedsAPersonIs(tester, '1 need you');
    });
    testWidgets('''a repository that cannot be reached for now is said on the project, and needs nobody''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theRepositoryOfCannotBeReachedForNow(tester, 'checkout');
      await theProjectSays(tester, 'checkout', 'The repository cannot be reached');
      await iGoToWhatNeedsAPerson(tester);
      await whatNeedsAPersonDoesNotNameTheProject(tester, 'checkout');
      await theCountOfWhatNeedsAPersonIs(tester, 'nothing needs you');
    });
    testWidgets('''a shut store is not an unreachable repository''', (tester) async {
      await bddSetUp(tester);
      await theRepositoryOfNeedsACredentialFromAShutStore(tester, 'checkout');
      await theProjectSays(tester, 'checkout', "This account's store is shut");
      await theProjectDoesNotSay(tester, 'checkout', 'cannot be reached');
    });
    testWidgets('''a project followed unverified says so, on its header and on its card''', (tester) async {
      await bddSetUp(tester);
      await theProjectIsFollowedUnverified(tester, 'checkout');
      await theProjectSays(tester, 'checkout', 'unverified');
      await theCardOfIsMarkedUnverified(tester, 'checkout');
    });
    testWidgets('''a project followed with a key is not marked unverified''', (tester) async {
      await bddSetUp(tester);
      await theProjectFollowsItsRepositoryAt(tester, 'checkout', '4f2a9c1e0b77');
      await theCardOfIsNotMarkedUnverified(tester, 'checkout');
    });
    testWidgets('''a rewritten history is taken from what needs a person, after agreeing''', (tester) async {
      await bddSetUp(tester);
      await theHistoryOfWasRewritten(tester, 'checkout');
      await iGoToWhatNeedsAPerson(tester);
      await whatNeedsAPersonNamesTheProject(tester, 'checkout');
      await iPress(tester, 'Take the rewritten history');
      await itSays(tester, 'Do this only if you rewrote the history yourself');
      await iPress(tester, 'Take it');
      await theMachineWasAskedToFollowTakingTheRewrittenHistory(tester, 'checkout');
    });
  });
}
