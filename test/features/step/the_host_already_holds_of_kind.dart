import 'package:flutter_test/flutter_test.dart';

import '../support/carrying.dart';
import '../support/world.dart';

/// Usage: the host already holds {'an-agent'} of kind {'api-key'}
Future<void> theHostAlreadyHoldsOfKind(WidgetTester tester, String name, String kind) async {
  (World.elsewhere as CarryingFakeBackend).holds(name, kind);
}
