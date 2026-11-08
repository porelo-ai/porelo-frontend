import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: no start named a model
///
/// Each start of several takes its repository's default on the machine, which knows it.
Future<void> noStartNamedAModel(WidgetTester tester) async {
  expect(World.backend.startedModels, isNotEmpty, reason: 'nothing was started');
  expect(World.backend.startedModels, everyElement(isNull));
}
