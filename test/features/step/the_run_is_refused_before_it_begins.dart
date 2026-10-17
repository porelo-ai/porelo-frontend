import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';

import '../support/world.dart';

/// Usage: the run is refused before it begins
Future<void> theRunIsRefusedBeforeItBegins(WidgetTester tester) async {
  // 69: nothing ran and nothing was created. More than one thing answers with it — no agent
  // installed, an unattended run whose credential could not be read — so what is said must be
  // true of all of them, and the daemon's own line carries which.
  World.backend.launch.addError(const OperationFailed(69));
  await World.backend.launch.close();
  await World.settle(tester);
}
