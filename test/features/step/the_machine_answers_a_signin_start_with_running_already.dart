import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine answers a sign-in start with {'porelo-login-an-agent'} running already
Future<void> theMachineAnswersASigninStartWithRunningAlready(WidgetTester tester, String task) async {
  World.backend.signInStartAnswer = SignInStarted(task: task, started: false);
}
