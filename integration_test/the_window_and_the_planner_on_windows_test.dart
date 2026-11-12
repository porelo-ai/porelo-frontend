// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import './step/the_interface_is_running.dart';
import './step/i_open_planning.dart';
import './step/the_board_appears_read_through_the_planner_on_this_computer.dart';
import './step/no_note_says_planning_is_not_offered.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('''The window and the planner on Windows''', () {
    testWidgets('''Planning shows the board, read through the planner on this computer''', (tester) async {
      await theInterfaceIsRunning(tester);
      await iOpenPlanning(tester);
      await theBoardAppearsReadThroughThePlannerOnThisComputer(tester);
      await noNoteSaysPlanningIsNotOffered(tester);
    });
  });
}
