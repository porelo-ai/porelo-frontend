import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine is slow to answer
Future<void> theMachineIsSlowToAnswer(WidgetTester tester) async {
  World.backend.readsTake = const Duration(seconds: 3);
}
