import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: a backend with nothing on it
///
/// A machine set up and answering, with no work and no project of the person's yet: a first start.
Future<void> aBackendWithNothingOnIt(WidgetTester tester) async {
  await World.startBackend(const <Task>[]);
  World.backend.theProjectsItHas = <Project>[];
}
