import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: starting says nothing answered from the upstream
Future<void> startingSaysNothingAnsweredFromTheUpstream(WidgetTester tester) async {
  World.backend.nextReadiness = const Readiness(
    ready: false,
    outcome: StartOutcome('UPSTREAM_UNREACHABLE'),
    agent: 'an-agent',
    provider: '',
    credential: '',
    detail: 'github.com did not answer within 10 seconds. Run: porelo doctor',
  );
}
