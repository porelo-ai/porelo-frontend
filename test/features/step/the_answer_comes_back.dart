import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the answer comes back
Future<void> theAnswerComesBack(WidgetTester tester) async {
  // The echo of our own Decide, on the same stream. It must not be applied twice, and until it
  // arrives the row stays: the answer is real when whatever asked has taken it.
  final answered = World.backend.decisions.last;
  final asked = World.fleet.clearance.waiting.firstWhere((prompt) => prompt.key == answered.key);
  World.backend.asking.add(World.settled(asked, answered.allow ? 'allow' : 'deny'));
  await World.settle(tester);
}
