import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: the planning phases follow the workflow
Future<void> thePlanningPhasesFollowTheWorkflow(WidgetTester tester) async {
  const names = ['Ideas', 'Analysis', 'Estimation', 'Backlog', 'Build', 'Done'];
  final positions = <double>[];
  for (final name in names) {
    final phase = planningElement('phase $name');
    expect(phase, findsOneWidget);
    positions.add(tester.getTopLeft(phase).dx);
  }
  for (var i = 1; i < positions.length; i++) {
    expect(positions[i], greaterThan(positions[i - 1]));
  }
}
