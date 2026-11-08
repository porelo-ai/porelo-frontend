import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: one start was sent
Future<void> oneStartWasSent(WidgetTester tester) async {
  expect(World.backend.starts, hasLength(1), reason: 'a refused start is never sent again by itself');
}
