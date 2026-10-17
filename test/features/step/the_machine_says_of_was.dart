import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine says {'msg-7.json'} of {'porelo-checkout-migrate'} was {'overridden'}
Future<void> theMachineSaysOfWas(WidgetTester tester, String message, String task, String event) async {
  World.backend.talking.add(TalkEvent(
      task: task, at: '2026-09-29T08:00:00Z', event: event, message: message, id: '', peer: 'reviewer', detail: ''));
  await World.settle(tester);
}
