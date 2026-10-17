import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/notifications.dart';

import '../support/world.dart';

/// Usage: it was told as something that cannot wait
Future<void> itWasToldAsSomethingThatCannotWait(WidgetTester tester) async {
  // The only thing here entitled to insist. The watcher gives up on its own, so a question that
  // waits politely behind everything else is one that expires.
  expect(World.notifier.raised.last.urgency, Urgency.waiting);
}
