import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';

/// Usage: planning story {id} is marked moved
Future<void> planningStoryIsMarkedMoved(WidgetTester tester, String id) async {
  // Removing the moved marker from an unfolded card makes this fail.
  expect(planningText(tester, planningElement('card $id')), contains('moved'));
}
