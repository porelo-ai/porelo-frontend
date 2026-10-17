// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_the_work.dart';
import './step/i_check_whether_this_machine_can_run_anything.dart';
import './step/it_says.dart';
import './step/the_machine_is_missing_because.dart';
import './step/the_machine_is_degraded_at_because.dart';
import './step/the_machine_cannot_establish.dart';
import './step/i_check_the_machine_again.dart';
import './step/the_machine_was_asked_twice_whether_it_can_run_anything.dart';
import './step/the_machine_cannot_answer_whether_it_can_run_anything.dart';

void main() {
  group('''Checking whether a machine can run work at all''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await iGoToTheWork(tester);
    }

    testWidgets('''whether this machine can run anything is one action away''', (tester) async {
      await bddSetUp(tester);
      await iCheckWhetherThisMachineCanRunAnything(tester);
      await itSays(tester, 'This machine can run work. Nothing is missing.');
    });
    testWidgets('''something missing is named, with what to do about it''', (tester) async {
      await bddSetUp(tester);
      await theMachineIsMissingBecause(tester, 'nft', 'no nftables binary on PATH');
      await iCheckWhetherThisMachineCanRunAnything(tester);
      await itSays(tester, 'This machine cannot run work: one thing it needs is missing.');
      await itSays(tester, 'no nftables binary on PATH');
      await itSays(tester, 'install nftables');
    });
    testWidgets('''a machine that runs work with something worth knowing is not called fine''', (tester) async {
      await bddSetUp(tester);
      await theMachineIsDegradedAtBecause(tester, 'rootless network backend', 'slirp4netns rather than pasta');
      await iCheckWhetherThisMachineCanRunAnything(tester);
      await itSays(tester, 'This machine runs work. One thing is worth knowing about.');
      await itSays(tester, 'slirp4netns rather than pasta');
    });
    testWidgets('''a check that could not be established says so rather than passing''', (tester) async {
      await bddSetUp(tester);
      await theMachineCannotEstablish(tester, 'SELinux policy');
      await iCheckWhetherThisMachineCanRunAnything(tester);
      await itSays(tester, 'could not be established');
      await itSays(tester, 'This machine runs work. One thing is worth knowing about.');
    });
    testWidgets('''the same check can be run again on demand''', (tester) async {
      await bddSetUp(tester);
      await iCheckWhetherThisMachineCanRunAnything(tester);
      await iCheckTheMachineAgain(tester);
      await theMachineWasAskedTwiceWhetherItCanRunAnything(tester);
    });
    testWidgets('''nothing here offers to fix the machine, and says so''', (tester) async {
      await bddSetUp(tester);
      await iCheckWhetherThisMachineCanRunAnything(tester);
      await itSays(tester, 'Nothing here installs or configures anything');
    });
    testWidgets('''a daemon too old to answer says so rather than showing a machine with nothing wrong''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theMachineCannotAnswerWhetherItCanRunAnything(tester);
      await iCheckWhetherThisMachineCanRunAnything(tester);
      await itSays(tester, 'this backend has no Doctor');
    });
  });
}
