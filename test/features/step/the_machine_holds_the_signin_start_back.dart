import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine holds the sign-in start back
Future<void> theMachineHoldsTheSigninStartBack(WidgetTester tester) async {
  World.backend.signInStartHeld = Completer<void>();
}
