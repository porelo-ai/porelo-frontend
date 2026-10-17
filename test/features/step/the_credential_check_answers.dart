import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the credential check answers {'NO_CREDENTIAL'}
Future<void> theCredentialCheckAnswers(WidgetTester tester, String outcome) async {
  World.backend.nextCheck = CredentialChecked(outcome: outcome, detail: 'as the machine said it');
}
