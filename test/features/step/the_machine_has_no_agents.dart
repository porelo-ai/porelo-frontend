import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine has no agents
Future<void> theMachineHasNoAgents(WidgetTester tester) async {
  World.backend.theAgentsItHas = <Agent>[];
}
