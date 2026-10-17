import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the upstream cannot be measured because {'NO_UPSTREAM'}
Future<void> theUpstreamCannotBeMeasuredBecause(
    WidgetTester tester, String reason) async {
  World.backend.theSyncAnswers = Synced(
    outcome: 'MEASURED',
    // Zero, and meaningless: the same number a project that is up to date answers.
    behind: 0,
    measured: false,
    reason: reason,
    detail: '',
  );
}
