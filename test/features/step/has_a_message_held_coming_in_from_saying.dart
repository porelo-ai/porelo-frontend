import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: {'porelo-checkout-shell'} has a message held coming in from {'partner'} saying {'here is the file'}
Future<void> hasAMessageHeldComingInFromSaying(WidgetTester tester, String task, String peer, String text) async {
  World.holdAMessage(
    task: task,
    peer: peer,
    text: text,
    standing: 'held',
    reason: 'from an external peer',
    direction: 'in',
  );
}
