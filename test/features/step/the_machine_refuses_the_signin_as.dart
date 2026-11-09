import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine refuses the sign-in as {'ALREADY_SIGNED_IN'}
///
/// Every sign-in start not forced is refused so; a forced one starts.
Future<void> theMachineRefusesTheSigninAs(WidgetTester tester, String reason) async {
  World.backend.signInRefusedAs = reason;
}
