import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the planning watch ends
Future<void> thePlanningWatchEnds(WidgetTester tester) async {
  await World.backend.endPlanning();
  await World.settle(tester);
}
