import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the launch named no model
///
/// Absent, not empty: absent the machine takes the provider's default, and a model meant for another
/// provider would mean nothing there.
Future<void> theLaunchNamedNoModel(WidgetTester tester) async {
  expect(World.backend.startedModels, isNotEmpty, reason: 'nothing was started');
  expect(World.backend.startedModels.last, isNull);
}
