import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: starting says the upstream refused the key, with {'tried the deploy key checkout-deploy. Run: porelo project key checkout'}
Future<void> startingSaysTheUpstreamRefusedTheKeyWith(WidgetTester tester, String detail) async {
  World.backend.nextReadiness = Readiness(
    ready: false,
    outcome: const StartOutcome('UPSTREAM_KEY_REFUSED'),
    agent: 'an-agent',
    provider: '',
    credential: '',
    detail: detail,
  );
}
