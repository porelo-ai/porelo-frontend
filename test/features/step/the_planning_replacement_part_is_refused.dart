import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: the planning replacement part {part} is refused
Future<void> thePlanningReplacementPartIsRefused(WidgetTester tester, String part) async {
  await refusePlanningReplacement(tester, part);
}
