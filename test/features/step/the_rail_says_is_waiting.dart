import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';

/// Usage: the rail says {'1'} is waiting
Future<void> theRailSaysIsWaiting(WidgetTester tester, String count) async {
  await lookingAtTheMachines(tester, () async {
    // On the machine's rail entry, not inside a view: a question with a deadline cannot be something
    // you find only by having gone to look in the right place.
    expect(find.descendant(of: railEntryFor(World.machines.current.name), matching: find.text(count)), findsOneWidget);
  });
}
