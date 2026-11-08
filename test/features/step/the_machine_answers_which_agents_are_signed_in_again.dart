import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine answers which agents are signed in again
Future<void> theMachineAnswersWhichAgentsAreSignedInAgain(WidgetTester tester) async {
  World.backend.signInsFail = null;
}
