import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the vault is open again
Future<void> theVaultIsOpenAgain(WidgetTester tester) async {
  World.backend.nextReadiness = null;
}
