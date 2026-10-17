import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine's Porelo cannot work on a project from here yet
Future<void> theMachinesPoreloCannotWorkOnAProjectFromHereYet(WidgetTester tester) async {
  World.backend.canBind = false;
}
