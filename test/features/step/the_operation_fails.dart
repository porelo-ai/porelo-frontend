import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';

import '../support/world.dart';

/// Usage: the operation fails
Future<void> theOperationFails(WidgetTester tester) async {
  // As a launch that ran and came back non-zero does: the operation happened, and it failed.
  World.backend.launch.addError(const OperationFailed(1));
  await World.backend.launch.close();
  await World.settle(tester);
}
