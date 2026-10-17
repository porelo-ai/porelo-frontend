import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the login stores what it signed in with
Future<void> theLoginStoresWhatItSignedInWith(WidgetTester tester) async {
  World.backend.nextReadiness = const Readiness(
    ready: true,
    outcome: StartOutcome.ready,
    agent: 'an-agent',
    provider: 'a-provider',
    credential: 'a-provider',
    detail: '',
  );
}
