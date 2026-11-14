import 'package:flutter_test/flutter_test.dart';

import '../support/carrying.dart';
import '../support/world.dart';

/// Usage: the host holds {'an-agent'} of kind {'api-key'}
Future<void> theHostHoldsOfKind(WidgetTester tester, String name, String kind) async {
  expect((World.elsewhere as CarryingFakeBackend).kindOf(name), kind, reason: 'what the host holds as $name');
}
