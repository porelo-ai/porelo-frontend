import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine holds its list of projects back
///
/// Every `Projects` asked from now waits until the scenario gives the list.
Future<void> theMachineHoldsItsListOfProjectsBack(WidgetTester tester) async {
  World.backend.projectsHeld = Completer<void>();
}
