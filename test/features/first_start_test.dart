// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_nothing_on_it.dart';
import './step/the_app_is_running.dart';
import './step/the_section_shown_is.dart';
import './step/the_first_step_is_done.dart';
import './step/it_says.dart';
import './step/i_choose_to_work_without_a_project_first.dart';
import './step/the_tunnel_drops.dart';
import './step/it_does_not_say.dart';
import './step/enough_time_passes_for_another_try.dart';
import './step/a_backend_with_work_on_it.dart';

void main() {
  group('''A first start led from a machine to a project to the first work''', () {
    testWidgets('''with no work anywhere, the work page leads through three steps''', (tester) async {
      await aBackendWithNothingOnIt(tester);
      await theAppIsRunning(tester);
      await theSectionShownIs(tester, 'Work');
      await theFirstStepIsDone(tester, 'machine', true);
      await theFirstStepIsDone(tester, 'project', false);
      await itSays(tester, 'From a repository you have');
      await iChooseToWorkWithoutAProjectFirst(tester);
      await theFirstStepIsDone(tester, 'project', true);
      await itSays(tester, 'Start the first work');
    });
    testWidgets('''a machine that does not answer is the first step still to take''', (tester) async {
      await aBackendWithNothingOnIt(tester);
      await theAppIsRunning(tester);
      await theTunnelDrops(tester);
      await theFirstStepIsDone(tester, 'machine', false);
      await itSays(tester, 'Set up a machine');
      await itDoesNotSay(tester, 'Start the first work');
      await enoughTimePassesForAnotherTry(tester);
      await theFirstStepIsDone(tester, 'machine', true);
    });
    testWidgets('''once there is work, the window shows it rather than the first steps''', (tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await itDoesNotSay(tester, 'Three steps, and the first work runs');
    });
  });
}
