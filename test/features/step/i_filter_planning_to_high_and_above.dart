import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';
import '../support/planning.dart';

/// Usage: i filter planning to high and above
Future<void> iFilterPlanningToHighAndAbove(WidgetTester tester) async {
  await tester.tap(planningElement('priority'));
  await World.settle(tester);
  await tester.tap(find.text('High and above').last);
  await World.settle(tester);
}
