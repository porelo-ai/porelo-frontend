import 'package:flutter_test/flutter_test.dart';

import '../support/planning.dart';
import '../support/world.dart';

/// Usage: the planning revision changes on the machine
Future<void> thePlanningRevisionChangesOnTheMachine(WidgetTester tester) async {
  final board = planningFixture();
  board['revision'] = 'another-revision';
  World.backend.planning['checkout'] = board;
}
