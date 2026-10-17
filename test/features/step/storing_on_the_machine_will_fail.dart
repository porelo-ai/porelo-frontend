import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: storing on the machine will fail
Future<void> storingOnTheMachineWillFail(WidgetTester tester) async {
  World.setup.storingFails = 'porelo: the vault is shut';
}
