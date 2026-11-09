import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: there are {count} pending planning moves
Future<void> thereArePendingPlanningMoves(WidgetTester tester, num count) async {
  expect(planningElement('moves-pending'), findsOneWidget);
  final rows = find.descendant(
    of: planningElement('detail'),
    matching: find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> && key.value.startsWith('planning-pending-move ');
    }),
  );
  expect(rows, findsNWidgets(count.toInt()));
  expect(planningElement('save-moves'), findsOneWidget);
}
