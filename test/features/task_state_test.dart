// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_the_work.dart';
import './step/i_select_the_project.dart';
import './step/the_work_is_waiting_on.dart';
import './step/the_work_is_shown_as.dart';
import './step/it_says_it_is_waiting_on.dart';
import './step/the_work_is_idle.dart';
import './step/the_work_is_dead.dart';
import './step/the_work_has_been_idle_since_minutes_ago.dart';
import './step/the_work_cannot_be_seen.dart';
import './step/the_work_is_not_shown_as.dart';
import './step/the_backend_says_it_is_waiting_on.dart';
import './step/the_work_holds_for.dart';
import './step/i_select_the_work.dart';
import './step/i_open_the_selection.dart';
import './step/the_detail_for_is_shown.dart';
import './step/it_says.dart';
import './step/the_work_holds_for_granted_by_at.dart';

void main() {
  group('''What a piece of work is doing, and how long it has been''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await iGoToTheWork(tester);
      await iSelectTheProject(tester, 'checkout');
    }

    testWidgets('''work waiting on a person says so, and says what it is waiting on''', (tester) async {
      await bddSetUp(tester);
      await theWorkIsWaitingOn(tester, 'porelo-checkout-shell', 'api.example.test:443');
      await theWorkIsShownAs(tester, 'porelo-checkout-shell', 'waiting');
      await itSaysItIsWaitingOn(tester, 'api.example.test:443');
    });
    testWidgets('''idle is told apart from finished''', (tester) async {
      await bddSetUp(tester);
      await theWorkIsIdle(tester, 'porelo-checkout-shell');
      await theWorkIsDead(tester, 'porelo-checkout-migrate');
      await theWorkIsShownAs(tester, 'porelo-checkout-shell', 'Quiet');
      await theWorkIsShownAs(tester, 'porelo-checkout-migrate', 'Not running');
    });
    testWidgets('''how long it has been that way is answerable''', (tester) async {
      await bddSetUp(tester);
      await theWorkHasBeenIdleSinceMinutesAgo(tester, 'porelo-checkout-shell', '40');
      await theWorkIsShownAs(tester, 'porelo-checkout-shell', 'Quiet for 40 minutes');
    });
    testWidgets('''work nothing can see is not reported as idle''', (tester) async {
      await bddSetUp(tester);
      await theWorkCannotBeSeen(tester, 'porelo-checkout-shell');
      await theWorkIsShownAs(tester, 'porelo-checkout-shell', 'Running');
      await theWorkIsNotShownAs(tester, 'porelo-checkout-shell', 'Quiet');
    });
    testWidgets('''a change of activity arrives without anybody asking for it''', (tester) async {
      await bddSetUp(tester);
      await theWorkIsIdle(tester, 'porelo-checkout-shell');
      await theBackendSaysItIsWaitingOn(tester, 'api.example.test:443');
      await theWorkIsShownAs(tester, 'porelo-checkout-shell', 'waiting');
    });
    testWidgets('''the credentials a task holds are shown with it''', (tester) async {
      await bddSetUp(tester);
      await theWorkHoldsFor(tester, 'porelo-checkout-migrate', 'a-provider', 'weather');
      await iSelectTheWork(tester, 'porelo-checkout-migrate');
      await iOpenTheSelection(tester);
      await theDetailForIsShown(tester, 'porelo-checkout-migrate');
      await itSays(tester, 'a-provider for weather, as PORELO_TOKEN_A_PROVIDER');
    });
    testWidgets('''a credential a person granted says who the task acts as''', (tester) async {
      await bddSetUp(tester);
      await theWorkHoldsForGrantedByAt(
        tester,
        'porelo-checkout-migrate',
        'jira',
        'jira',
        'alice',
        '2026-09-30T05:40:00Z',
      );
      await iSelectTheWork(tester, 'porelo-checkout-migrate');
      await iOpenTheSelection(tester);
      await itSays(tester, 'jira for jira, as PORELO_TOKEN_JIRA, granted by alice at 2026-09-30T05:40:00Z');
    });
  });
}
