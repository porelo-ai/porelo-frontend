import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: I remove the planning provider
Future<void> iRemoveThePlanningProvider(WidgetTester tester) async {
  await removePlanningProvider(tester);
}
