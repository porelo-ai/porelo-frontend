import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: planning story {id} shows refusal {words}
Future<void> planningStoryShowsRefusal(WidgetTester tester, String id, String words) async {
  // Dropping the per-card daemon reason from either card layout makes this fail.
  expect(planningText(tester, planningElement('card $id')), contains(words));
}
