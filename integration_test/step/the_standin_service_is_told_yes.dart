import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/remote.dart';
import 'the_test_machine_has_an_entry_a_standin_service_grants.dart';

/// Usage: the stand-in service is told yes
Future<void> theStandinServiceIsToldYes(WidgetTester tester) async {
  // What a person deciding in the browser does, as far as the service is concerned.
  await onTheTestMachine('curl -fs http://127.0.0.1:$standInPort/approve >/dev/null');
  // The machine asks the service again at its own pace, and only then does the interface hear it.
  await pumpUntil(
    tester,
    () => find.byKey(const Key('grant-settled')).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 60),
    what: 'the machine to hear the decision',
  );
}
