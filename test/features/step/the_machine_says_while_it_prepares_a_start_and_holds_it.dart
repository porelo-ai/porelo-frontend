import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine says {'Building the image'} while it prepares a start, and holds it
Future<void> theMachineSaysWhileItPreparesAStartAndHoldsIt(WidgetTester tester, String words) async {
  // As Porelo prepares: a step of the image, then nothing until the agent runs.
  World.backend
    ..startSays = <StartEvent>[StartStep(step: 'IMAGE', state: 'RUNNING', text: words, waitingOn: '', cause: '')]
    ..startHeld = Completer<void>();
}
