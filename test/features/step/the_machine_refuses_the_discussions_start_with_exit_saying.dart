import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/client/porelo_client.dart';

import '../support/world.dart';

/// Usage: the machine refuses the discussion's Start with exit {78}, saying {'porelo: no-homeserver'}
Future<void> theMachineRefusesTheDiscussionsStartWithExitSaying(WidgetTester tester, int code, String words) async {
  World.backend.discussionAnswer = StartProgress(exitCode: code, output: [words, 'porelo: nothing was created']);
}
