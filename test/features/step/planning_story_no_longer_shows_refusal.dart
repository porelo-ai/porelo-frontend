import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: planning story {id} no longer shows refusal {words}
Future<void> planningStoryNoLongerShowsRefusal(WidgetTester tester, String id, String words) async {
  // Keeping an earlier save's reason on a card the newer save answered makes this fail.
  expect(planningText(tester, planningElement('card $id')), isNot(contains(words)));
}
