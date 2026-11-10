import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/work_page.dart';
import 'package:porelo_planning/porelo_planning.dart';

/// Usage: the work page is shown
Future<void> theWorkPageIsShown(WidgetTester tester) async {
  // Ignoring the confirmed navigation makes these fail on the actual page widgets.
  expect(find.byType(WorkPage), findsOneWidget);
  expect(find.byType(PlanningScreen), findsNothing);
}
