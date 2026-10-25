import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

import 'package:porelo_frontend/client.dart';

/// Usage: removing a room member is refused with {'The transport refused.'}
Future<void> removingARoomMemberIsRefusedWith(WidgetTester tester, String message) async {
  World.backend.memberRemovalRefusal = VarlinkException('org.fuin.porelo.Tasks1.ConversationRefused', <String, dynamic>{
    'message': message,
    'code': 77,
  });
}
