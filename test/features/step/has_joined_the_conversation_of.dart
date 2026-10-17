import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: {'anna'} has joined the conversation of {'checkout'}
Future<void> hasJoinedTheConversationOf(WidgetTester tester, String person, String project) async {
  World.backend.membersOf
      .putIfAbsent(project, () => <MessageMember>[])
      .add(MessageMember(person: person, user: '@$person:localhost'));
}
