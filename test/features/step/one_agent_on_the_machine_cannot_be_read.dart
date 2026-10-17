import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: one agent on the machine cannot be read
Future<void> oneAgentOnTheMachineCannotBeRead(WidgetTester tester) async {
  World.backend.theAgentsItCannotRead = const <String, String>{'broken-agent': 'its manifest could not be parsed'};
}
