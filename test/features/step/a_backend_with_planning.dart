import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: a backend with planning
Future<void> aBackendWithPlanning(WidgetTester tester) async {
  await World.startBackend(World.work);
  World.backend.theProjectsItHas = [
    Project.from({'name': 'checkout'}),
  ];
}
