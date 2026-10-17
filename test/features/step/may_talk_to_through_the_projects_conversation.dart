import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: {'porelo-checkout-migrate'} may talk to {'alice'} through the project's conversation, {'external'}
///
/// A peer at `matrix:`, as a project names a person reading its room, or as Porelo lists the
/// project's other work (`vouched`).
Future<void> mayTalkToThroughTheProjectsConversation(WidgetTester tester, String task, String peer, String trust) async {
  World.backend.peersOf.putIfAbsent(task, () => <TalkPeer>[]).add(
      TalkPeer(name: peer, address: 'matrix:', trust: trust, perDay: 200, mode: 'prompt', held: false));
}
