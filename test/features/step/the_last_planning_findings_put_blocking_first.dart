import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: the last planning findings put blocking first
Future<void> theLastPlanningFindingsPutBlockingFirst(WidgetTester tester) async {
  expectPlanningFindings(tester);
}
