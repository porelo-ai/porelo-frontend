// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_app_is_running.dart';
import './step/the_project_has_the_repositories.dart';
import './step/the_project_is_followed_from.dart';
import './step/i_go_to_the_work.dart';
import './step/i_select_the_project.dart';
import './step/i_check_the_project_now.dart';
import './step/the_machine_was_asked_to_refresh.dart';
import './step/the_upstream_was_asked_about.dart';
import './step/it_says.dart';
import './step/the_machine_takes_its_time_to_refresh.dart';
import './step/the_machine_answers_the_refresh.dart';
import './step/it_does_not_say.dart';
import './step/the_next_refresh_finds.dart';
import './step/the_machine_no_longer_follows.dart';

void main() {
  group('''Checking a followed project now, not at the next round''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await theProjectHasTheRepositories(tester, 'checkout', 'checkout, payments-api');
      await theProjectIsFollowedFrom(tester, 'checkout', 'git@example.org:checkout.git');
      await iGoToTheWork(tester);
      await iSelectTheProject(tester, 'checkout');
    }

    testWidgets('''checking fetches the project and asks each repository, and says what it found''', (tester) async {
      await bddSetUp(tester);
      await iCheckTheProjectNow(tester);
      await theMachineWasAskedToRefresh(tester, 'checkout');
      await theUpstreamWasAskedAbout(tester, 'checkout');
      await itSays(tester, 'Following, at c0ffee1');
      await itSays(tester, 'payments-api: 3 commits behind the upstream, as of now');
    });
    testWidgets('''while the machine fetches, the page says it is checking''', (tester) async {
      await bddSetUp(tester);
      await theMachineTakesItsTimeToRefresh(tester);
      await iCheckTheProjectNow(tester);
      await itSays(tester, 'checking…');
      await theMachineAnswersTheRefresh(tester);
      await itDoesNotSay(tester, 'checking…');
      await itSays(tester, 'Following, at c0ffee1');
    });
    testWidgets('''a fetch that failed says why, in the machine's terms''', (tester) async {
      await bddSetUp(tester);
      await theNextRefreshFinds(tester, 'VAULT_LOCKED');
      await iCheckTheProjectNow(tester);
      await itSays(tester, "This account's store is shut, and the repository needs a credential from it");
    });
    testWidgets('''a project this account no longer follows says so, rather than nothing''', (tester) async {
      await bddSetUp(tester);
      await theMachineNoLongerFollows(tester, 'checkout');
      await iCheckTheProjectNow(tester);
      await itSays(tester, 'checkout is no longer followed here');
    });
  });
}
