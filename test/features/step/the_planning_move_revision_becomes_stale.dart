import 'package:flutter_test/flutter_test.dart';

import '../support/planning_details.dart';

/// Usage: the planning move revision becomes stale
Future<void> thePlanningMoveRevisionBecomesStale(WidgetTester tester) async {
  stalePlanningMoves();
}
