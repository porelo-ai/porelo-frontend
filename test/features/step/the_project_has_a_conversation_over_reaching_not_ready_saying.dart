import 'package:flutter_test/flutter_test.dart';

import 'the_project_has_a_conversation_over_reaching_ready.dart';

/// Usage: the project {'checkout'} has a conversation over {'matrix'} reaching {'127.0.0.1:8008'}, not ready saying {'the homeserver does not answer'}
Future<void> theProjectHasAConversationOverReachingNotReadySaying(
  WidgetTester tester,
  String name,
  String transport,
  String reaches,
  String detail,
) => conversing(tester, name, transport, reaches, ready: false, detail: detail);
