import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine answers whether work can start again
Future<void> theMachineAnswersWhetherWorkCanStartAgain(WidgetTester tester) async {
  World.backend.canStartFails = null;
}
