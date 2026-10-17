import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the work {'porelo-checkout-shell'} is waiting on {'api.example.test:443'}
Future<void> theWorkIsWaitingOn(
    WidgetTester tester, String work, String destination) async {
  // Said by whatever asked the question, never guessed from how long it has been quiet.
  World.theWorkIs(work, activity: 'WAITING', waitingFor: destination);
  await World.settle(tester);
}
