import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: no ordered task was started twice on this machine
Future<void> noOrderedTaskWasStartedTwiceOnThisMachine(WidgetTester tester) async {
  await World.settle(tester);
  final ordered = World.backend.startsOrdered.whereType<String>().toList();
  // A follow-up started by the window beside the run that refused it makes this fail.
  expect(ordered.toSet(), hasLength(ordered.length), reason: '$ordered');
}
