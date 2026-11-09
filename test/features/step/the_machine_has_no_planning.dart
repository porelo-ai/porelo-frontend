import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine has no planning
Future<void> theMachineHasNoPlanning(WidgetTester tester) async {
  World.backend.withoutPlanning = true;
  World.backend.failPlanning(const FeatureNotSupported('planning'));
  await World.settle(tester);
}
