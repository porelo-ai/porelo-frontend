// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_the_work.dart';
import './step/i_select_the_project.dart';
import './step/the_project_has_the_repositories.dart';
import './step/the_machine_says_the_repository_is_commits_ahead_of_central.dart';
import './step/i_open_from_the_projects_of_this_machine.dart';
import './step/i_press.dart';
import './step/it_says.dart';
import './step/nothing_was_brought_to_central.dart';
import './step/central_was_asked_for.dart';
import './step/the_repository_says.dart';
import './step/the_machine_says_the_repository_stands_against_central_with_no_count.dart';
import './step/the_page_offers_no.dart';
import './step/the_central_forge_refuses_the_token.dart';
import './step/it_does_not_say.dart';

void main() {
  group('''A host's finished main brought to central from its project's page''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await iGoToTheWork(tester);
      await iSelectTheProject(tester, 'checkout');
      await theProjectHasTheRepositories(tester, 'checkout', 'checkout, payments-api, billing');
    }

    testWidgets('''work ahead of central is brought there once the person agrees''', (tester) async {
      await bddSetUp(tester);
      await theMachineSaysTheRepositoryIsCommitsAheadOfCentral(tester, 'payments-api', 3);
      await iOpenFromTheProjectsOfThisMachine(tester, 'checkout');
      await iPress(tester, 'Bring it to central…');
      await itSays(tester, '3 commits of payments-api');
      await nothingWasBroughtToCentral(tester);
      await iPress(tester, 'Bring them to central');
      await centralWasAskedFor(tester, 'payments-api');
      await itSays(tester, 'Brought to central: payments-api');
      await theRepositorySays(tester, 'payments-api', 'at central');
    });
    testWidgets('''work the person does not agree to bring stays on the host''', (tester) async {
      await bddSetUp(tester);
      await theMachineSaysTheRepositoryIsCommitsAheadOfCentral(tester, 'payments-api', 3);
      await iOpenFromTheProjectsOfThisMachine(tester, 'checkout');
      await iPress(tester, 'Bring it to central…');
      await iPress(tester, 'Cancel');
      await nothingWasBroughtToCentral(tester);
      await theRepositorySays(tester, 'payments-api', '3 commits ahead of central');
    });
    testWidgets('''a host whose main is at central offers nothing to bring''', (tester) async {
      await bddSetUp(tester);
      await theMachineSaysTheRepositoryStandsAgainstCentralWithNoCount(tester, 'payments-api', 'up-to-date');
      await iOpenFromTheProjectsOfThisMachine(tester, 'checkout');
      await thePageOffersNo(tester, 'Bring it to central…');
    });
    testWidgets('''a token the central forge refuses is said as refused''', (tester) async {
      await bddSetUp(tester);
      await theMachineSaysTheRepositoryIsCommitsAheadOfCentral(tester, 'payments-api', 3);
      await theCentralForgeRefusesTheToken(tester);
      await iOpenFromTheProjectsOfThisMachine(tester, 'checkout');
      await iPress(tester, 'Bring it to central…');
      await iPress(tester, 'Bring them to central');
      await itSays(tester, 'refused the token');
      await itDoesNotSay(tester, 'Brought to central');
      await theRepositorySays(tester, 'payments-api', '3 commits ahead of central');
    });
  });
}
