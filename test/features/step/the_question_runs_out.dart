import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the question runs out
Future<void> theQuestionRunsOut(WidgetTester tester) async {
  // The watcher gives up on its own timeout and says so on the same stream. Nothing asks about it
  // again, so a question that merely stopped arriving would be indistinguishable from one still
  // waiting for its operator.
  World.backend.asking.add(World.settled(World.blocked('api.example.test:443'), 'timeout'));
  await World.settle(tester);
}
