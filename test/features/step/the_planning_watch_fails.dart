import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the planning watch fails
Future<void> thePlanningWatchFails(WidgetTester tester) async {
  World.backend.failPlanning(
    const VarlinkException('org.fuin.porelo.Tasks1.WorkNotAllowed', {'detail': 'Planning store cannot be read'}),
  );
  await World.settle(tester);
}
