import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: the machine reports an empty planning finding file
Future<void> theMachineReportsAnEmptyPlanningFindingFile(WidgetTester tester) async {
  reportEmptyFindingFile();
}
