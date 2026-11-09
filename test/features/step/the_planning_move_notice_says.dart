import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: the planning move notice says {words}
Future<void> thePlanningMoveNoticeSays(WidgetTester tester, String words) async {
  expect(planningText(tester, planningElement('move-notice')), contains(words));
}
