import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: nothing was brought to central
Future<void> nothingWasBroughtToCentral(WidgetTester tester) async {
  expect(World.backend.centralPushes, isEmpty);
}
