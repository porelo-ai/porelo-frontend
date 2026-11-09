import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: planning story {id} is not marked moved
Future<void> planningStoryIsNotMarkedMoved(WidgetTester tester, String id) async {
  // Marking every pending card as moved, including refusals, makes this fail.
  expect(planningText(tester, planningElement('card $id')), isNot(contains('moved')));
}
