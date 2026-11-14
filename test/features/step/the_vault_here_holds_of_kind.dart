import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the vault here holds {'an-agent'} of kind {'oauth'}
Future<void> theVaultHereHoldsOfKind(WidgetTester tester, String name, String kind) async {
  World.here.holds(name, kind);
}
