import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: I press planning back
Future<void> iPressPlanningBack(WidgetTester tester) async {
  await planningBack(tester);
}
