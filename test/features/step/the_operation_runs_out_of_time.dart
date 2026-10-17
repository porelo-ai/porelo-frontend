import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';

import '../support/world.dart';

/// Usage: the operation runs out of time
Future<void> theOperationRunsOutOfTime(WidgetTester tester) async {
  // 124: killed by its own limit rather than by going wrong. The log is kept, deliberately, so
  // what it managed to do is still the interesting part.
  World.backend.launch.addError(const OperationFailed(124));
  await World.backend.launch.close();
  await World.settle(tester);
}
