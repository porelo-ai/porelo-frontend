import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the backend says it is waiting on {'api.example.test:443'}
Future<void> theBackendSaysItIsWaitingOn(WidgetTester tester, String destination) async {
  // Through Watch, which redraws on activity now — that was the one transition a watcher would
  // otherwise never show, since the runtime's own words do not change when work starts waiting.
  World.theWorkIs('porelo-checkout-shell', activity: 'WAITING', waitingFor: destination);
  await World.settle(tester);
}
