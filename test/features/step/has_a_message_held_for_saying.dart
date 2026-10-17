import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: {'porelo-checkout-shell'} has a message held for {'reviewer'} saying {'please look at the diff'}
Future<void> hasAMessageHeldForSaying(WidgetTester tester, String task, String peer, String text) async {
  World.holdAMessage(task: task, peer: peer, text: text, standing: 'held', reason: 'moderation: prompt');
}
