import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';
import '../support/world.dart';

/// Usage: I search planning for {query}
Future<void> iSearchPlanningFor(WidgetTester tester, String query) async {
  await tester.enterText(planningElement('search'), query);
  await World.settle(tester);
}
