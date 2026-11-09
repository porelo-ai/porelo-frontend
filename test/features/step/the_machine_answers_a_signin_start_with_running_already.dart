import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine answers a sign-in start with {'porelo-login-an-agent'} running already
///
/// Started meanwhile from a terminal at the machine: the list read before says none runs, and only the start's
/// answer (`started` false) names it.
Future<void> theMachineAnswersASigninStartWithRunningAlready(WidgetTester tester, String container) async {
  World.backend.runningSinceTheList = container;
}
