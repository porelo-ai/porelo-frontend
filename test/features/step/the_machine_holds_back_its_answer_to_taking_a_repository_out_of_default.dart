import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine holds back its answer to taking a repository out of default
Future<void> theMachineHoldsBackItsAnswerToTakingARepositoryOutOfDefault(WidgetTester tester) async {
  World.backend.leaveHeld = Completer<void>();
}
