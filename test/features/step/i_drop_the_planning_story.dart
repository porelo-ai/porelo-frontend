import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';
import '../support/world.dart';

/// Usage: I drop the planning story
Future<void> iDropThePlanningStory(WidgetTester tester) async {
  await planningDrag!.up();
  planningDrag = null;
  await World.settle(tester);
}
