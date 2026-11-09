import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: the planning states put working states first
Future<void> thePlanningStatesPutWorkingStatesFirst(WidgetTester tester) async {
  for (final pair in [('Implementing', 'Review'), ('Reworking', 'Review')]) {
    final first = planningElement('state ${pair.$1}'), second = planningElement('state ${pair.$2}');
    expect(first, findsOneWidget);
    expect(second, findsOneWidget);
    expect(tester.getTopLeft(first).dy, lessThan(tester.getTopLeft(second).dy));
  }
}
