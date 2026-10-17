import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine trusts {'SHA256:…'} for {'example.org'}, and nothing else
Future<void> theMachineTrustsForAndNothingElse(WidgetTester tester, String fingerprint, String host) async {
  expect(World.backend.trustedHostKeys, <String, List<String>>{
    host: <String>[fingerprint],
  });
}
