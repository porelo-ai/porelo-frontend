import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';

import '../support/world.dart';

/// Usage: the machine refuses the start as {'NOT_READY'}
Future<void> theMachineRefusesTheStartAs(WidgetTester tester, String action) async {
  // A refusal is `Start`'s final reply, which the backend turns into this.
  final refused = World.backend.launch;
  refused.addError(StartRefused(StartAction(action)));
  unawaited(refused.close());
  await World.settle(tester);
}
