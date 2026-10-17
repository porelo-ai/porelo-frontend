import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: {'porelo-checkout-migrate'} may talk to {'reviewer'}, {'vouched'}, in {'prompt'}, having sent {'3'} and received {'1'} today
Future<void> mayTalkToInHavingSentAndReceivedToday(
    WidgetTester tester, String task, String peer, String trust, String mode, String sent, String received) async {
  World.backend.peersOf.putIfAbsent(task, () => <TalkPeer>[]).add(TalkPeer(
      name: peer,
      address: 'local:$peer',
      trust: trust,
      perDay: 20,
      mode: mode,
      held: false,
      sentToday: int.parse(sent),
      receivedToday: int.parse(received)));
}
