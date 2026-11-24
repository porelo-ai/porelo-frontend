import 'package:flutter_test/flutter_test.dart';

import '../support/held_saves.dart';
import '../support/world.dart';

/// Usage: Needs you holds the held saves of {'checkout'}
Future<void> needsYouHoldsTheHeldSavesOf(WidgetTester tester, String project) async {
  expect(heldSavesInNeedsYou(project), findsOneWidget);
  // The title says which machine's planner holds them.
  expect(find.text('Held saves · $project on ${World.machines.current.name}'), findsOneWidget);
}
