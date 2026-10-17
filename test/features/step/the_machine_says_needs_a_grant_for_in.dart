import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine says {'jira'} needs a grant for {'porelo-checkout-shell'} in {'checkout'}
Future<void> theMachineSaysNeedsAGrantForIn(WidgetTester tester, String entry, String task, String project) =>
    needing(tester, entry, task, project, 'never');

/// Streams that [entry] needs authorizing, as the machine raises it.
Future<void> needing(WidgetTester tester, String entry, String task, String project, String state) async {
  World.backend.needing.add(AuthorizationNeeded(
      credential: entry, task: task, project: project, state: state, at: '2026-09-30T08:40:00Z'));
  await World.settle(tester);
}
