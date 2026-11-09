import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/rehearsal.dart';

/// Usage: the host's login of that agent still runs
Future<void> theHostsLoginOfThatAgentStillRuns(WidgetTester tester) => pictured(tester, () async {
  if (Rehearsal.notRun != null) return;
  // Left to end by itself: a login nobody finishes ends on the host after 30 minutes.
  await pumpFor(tester, const Duration(seconds: 5));
  final running = await theSignInsRunningOnTheHost();
  final ofTheAgent = running.keys.where(Rehearsal.notSignedIn.contains).toList();
  expect(
    ofTheAgent,
    isNotEmpty,
    reason:
        'a login of an agent the host said was not signed in (${Rehearsal.notSignedIn}) runs after its terminal '
        'closed; running: $running',
  );
});
