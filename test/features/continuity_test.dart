// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_the_work.dart';
import './step/i_select_the_project.dart';
import './step/i_ask_to_close_it.dart';
import './step/it_says_keeps_running.dart';
import './step/work_is_blocked_reaching.dart';
import './step/it_says.dart';
import './step/i_stay.dart';
import './step/the_app_is_still_open.dart';
import './step/i_select_the_work.dart';
import './step/the_app_is_restarted.dart';
import './step/the_project_is_selected.dart';
import './step/the_work_is_still_selected.dart';
import './step/i_show_what_this_session_has_run.dart';
import './step/the_section_shown_is.dart';
import './step/a_newer_build_is_installed_underneath.dart';
import './step/it_says_a_newer_build_is_installed.dart';

void main() {
  group('''Leaving and reopening the window without losing where you were''',
      () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await iGoToTheWork(tester);
    }

    testWidgets('''leaving says what carries on without the window''',
        (tester) async {
      await bddSetUp(tester);
      await iSelectTheProject(tester, 'checkout');
      await iAskToCloseIt(tester);
      await itSaysKeepsRunning(tester, 'porelo-checkout-shell');
    });
    testWidgets(
        '''a decision that nothing will be listening for is said before leaving''',
        (tester) async {
      await bddSetUp(tester);
      await workIsBlockedReaching(tester, 'api.example.test:443');
      await iAskToCloseIt(tester);
      await itSays(
          tester, 'Nothing will be listening for them once this closes');
    });
    testWidgets('''staying changes nothing''', (tester) async {
      await bddSetUp(tester);
      await iAskToCloseIt(tester);
      await iStay(tester);
      await theAppIsStillOpen(tester);
    });
    testWidgets('''reopening comes back to the same selection''',
        (tester) async {
      await bddSetUp(tester);
      await iSelectTheProject(tester, 'checkout');
      await iSelectTheWork(tester, 'porelo-checkout-shell');
      await theAppIsRestarted(tester);
      await iGoToTheWork(tester);
      await theProjectIsSelected(tester, 'checkout');
      await theWorkIsStillSelected(tester, 'porelo-checkout-shell');
    });
    testWidgets('''reopening opens on the work, whichever section was left''',
        (tester) async {
      await bddSetUp(tester);
      await iShowWhatThisSessionHasRun(tester);
      await theAppIsRestarted(tester);
      await theSectionShownIs(tester, 'Work');
    });
    testWidgets(
        '''a newer build installed underneath says so, and changes nothing on its own''',
        (tester) async {
      await bddSetUp(tester);
      await aNewerBuildIsInstalledUnderneath(tester);
      await itSaysANewerBuildIsInstalled(tester);
      await theAppIsStillOpen(tester);
    });
  });
}
