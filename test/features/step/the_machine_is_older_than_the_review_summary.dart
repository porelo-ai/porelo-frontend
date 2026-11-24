import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine is older than the review summary
Future<void> theMachineIsOlderThanTheReviewSummary(WidgetTester tester) async {
  World.backend.summaryIsMissing = true;
}
