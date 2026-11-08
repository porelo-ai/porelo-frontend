import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the launch named the model {'big-model'}
Future<void> theLaunchNamedTheModel(WidgetTester tester, String model) async {
  expect(World.backend.startedModels, isNotEmpty, reason: 'nothing was started');
  expect(World.backend.startedModels.last, model);
}
