// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_the_work.dart';
import './step/the_machine_is_reached_over_ssh_as.dart';
import './step/i_open_the_ssh_console_of.dart';
import './step/the_console_runs.dart';
import './step/this_computer_offers_no_ssh_console.dart';

void main() {
  group('''A machine reached over ssh opens a shell in the window''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await iGoToTheWork(tester);
    }

    testWidgets('''a machine reached over ssh opens its SSH Console in a terminal in the window''', (tester) async {
      await bddSetUp(tester);
      await theMachineIsReachedOverSshAs(tester, 'alice@vm');
      await iOpenTheSshConsoleOf(tester, 'vm');
      await theConsoleRuns(tester, 'ssh -t alice@vm');
    });
    testWidgets('''this computer offers no SSH Console''', (tester) async {
      await bddSetUp(tester);
      await thisComputerOffersNoSshConsole(tester);
    });
  });
}
