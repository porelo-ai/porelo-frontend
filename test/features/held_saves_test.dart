// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_planning.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_what_needs_a_person.dart';
import './step/the_planner_holds_a_save_of_made_on_the_board.dart';
import './step/needs_you_holds_the_held_saves_of.dart';
import './step/the_held_save_of_offers.dart';
import './step/needs_you_counts.dart';
import './step/i_resend_the_held_save_of.dart';
import './step/needs_you_holds_no_held_saves_of.dart';
import './step/the_planner_was_asked_to_the_held_save_of.dart';
import './step/the_planner_holds_a_save_of_made_by_a_halted_run.dart';
import './step/i_drop_the_held_save_of.dart';
import './step/the_planner_refuses_to_resend_a_save_as_no_longer_held.dart';
import './step/the_held_saves_of_say.dart';

void main() {
  group('''Saves the planner holds wait in Needs you until resent or dropped''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithPlanning(tester);
      await theAppIsRunning(tester);
      await iGoToWhatNeedsAPerson(tester);
    }

    testWidgets('''A save made on the board is held with Resend and Drop, and Resend clears it''', (tester) async {
      await bddSetUp(tester);
      await thePlannerHoldsASaveOfMadeOnTheBoard(tester, 'ST293');
      await needsYouHoldsTheHeldSavesOf(tester, 'checkout');
      await theHeldSaveOfOffers(tester, 'ST293', 'Resend and Drop');
      await needsYouCounts(tester, 2);
      await iResendTheHeldSaveOf(tester, 'ST293');
      await needsYouHoldsNoHeldSavesOf(tester, 'checkout');
      await needsYouCounts(tester, 1);
      await thePlannerWasAskedToTheHeldSaveOf(tester, 'resend', 'ST293');
    });
    testWidgets('''A halted run's held save can only be dropped''', (tester) async {
      await bddSetUp(tester);
      await thePlannerHoldsASaveOfMadeByAHaltedRun(tester, 'ST293');
      await needsYouHoldsTheHeldSavesOf(tester, 'checkout');
      await theHeldSaveOfOffers(tester, 'ST293', 'Drop only');
    });
    testWidgets('''Drop removes a held save and writes nothing''', (tester) async {
      await bddSetUp(tester);
      await thePlannerHoldsASaveOfMadeByAHaltedRun(tester, 'ST293');
      await iDropTheHeldSaveOf(tester, 'ST293');
      await needsYouHoldsNoHeldSavesOf(tester, 'checkout');
      await thePlannerWasAskedToTheHeldSaveOf(tester, 'drop', 'ST293');
    });
    testWidgets('''A refused resend says the planner's reason and keeps the save''', (tester) async {
      await bddSetUp(tester);
      await thePlannerRefusesToResendASaveAsNoLongerHeld(tester);
      await thePlannerHoldsASaveOfMadeOnTheBoard(tester, 'ST293');
      await iResendTheHeldSaveOf(tester, 'ST293');
      await theHeldSavesOfSay(tester, 'checkout', 'The save is not held: it runs, or was sent again.');
      await needsYouHoldsTheHeldSavesOf(tester, 'checkout');
    });
  });
}
