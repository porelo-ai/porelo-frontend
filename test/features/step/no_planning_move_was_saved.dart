import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: no planning move was saved
Future<void> noPlanningMoveWasSaved(WidgetTester tester) async {
  // Saving before the person answered the warning, or for a drop that starts work, makes this fail.
  expect(World.planning.moveCalls, isEmpty);
}
