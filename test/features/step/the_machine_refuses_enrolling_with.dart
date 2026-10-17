import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine refuses enrolling with {'VAULT_WITHOUT_KEYSLOTS'}
Future<void> theMachineRefusesEnrollingWith(WidgetTester tester, String outcome) async {
  World.backend.enrollingAnswers = KeyslotOutcome(outcome);
}
