import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/idea_walk.dart';
import '../support/planner_moves.dart';

/// Usage: the Reworking dialog is open and no task was started
Future<void> theReworkingDialogIsOpenAndNoTaskWasStarted(WidgetTester tester) =>
    walked(tester, '11 [needs-you-offer] read: the Reworking dialog is open and no task was started', () async {
      final dialog = find.byType(Dialog);
      await pumpUntil(tester, () => dialog.evaluate().isNotEmpty, what: 'a dialog opened from the entry');
      final rework = find.descendant(of: dialog, matching: find.textContaining('Rework'));
      if (rework.evaluate().isEmpty) fail('asked the dialog opened from the entry for Reworking; it does not say so');
      final now = {for (final each in await theProjectsTasks()) theContainerOf(each)};
      final started = now.difference(PlannerMoves.tasksBeforeOpening);
      // Put away unanswered, as a person who only looked.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await pumpFor(tester);
      if (started.isNotEmpty) fail('asked for no task started by opening the entry; ${started.join(', ')} started');
    });
