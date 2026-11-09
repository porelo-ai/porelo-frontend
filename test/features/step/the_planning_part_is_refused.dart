import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: the planning part {part} is refused
Future<void> thePlanningPartIsRefused(WidgetTester tester, String part) async {
  refusePlanningPart(part);
}
