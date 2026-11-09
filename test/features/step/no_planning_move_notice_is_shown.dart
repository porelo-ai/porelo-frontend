import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: no planning move notice is shown
Future<void> noPlanningMoveNoticeIsShown(WidgetTester tester) async {
  expect(planningElement('move-notice'), findsNothing);
}
