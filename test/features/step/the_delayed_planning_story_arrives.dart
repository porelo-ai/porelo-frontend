import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: the delayed planning story arrives
Future<void> theDelayedPlanningStoryArrives(WidgetTester tester) async {
  await releasePlanningStory(tester);
}
