import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';
import '../support/world.dart';

/// Usage: I save planning moves
Future<void> iSavePlanningMoves(WidgetTester tester) async {
  await tester.tap(planningElement('save'));
  await World.settle(tester);
}
