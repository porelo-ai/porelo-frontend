import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/planning_view.dart';
import 'package:porelo_frontend/src/ui/work_page.dart';

/// Usage: the work page is shown
Future<void> theWorkPageIsShown(WidgetTester tester) async {
  // Ignoring the confirmed navigation makes these fail on the actual page widgets.
  expect(find.byType(WorkPage), findsOneWidget);
  expect(find.byType(PlanningView), findsNothing);
}
