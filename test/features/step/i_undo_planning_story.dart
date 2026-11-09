import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';
import '../support/world.dart';

/// Usage: I undo planning story {id}
Future<void> iUndoPlanningStory(WidgetTester tester, String id) async {
  await tester.tap(planningElement('undo $id'));
  await World.settle(tester);
}
