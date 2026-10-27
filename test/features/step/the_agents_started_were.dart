import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the agents started were {'payments-api/an-agent/payments-api, ledger/other-agent/ledger'}
///
/// Each as `repository/agent/task`, in the order sent: attended, with no prompt, and answered once
/// the task exists rather than after its build.
Future<void> theAgentsStartedWere(WidgetTester tester, String starts) async {
  final sent = World.backend.starts;
  expect(<String>[
    for (final each in sent) '${each.repository}/${each.agent}/${each.task}',
  ], starts.split(',').map((each) => each.trim()).toList());
  expect(sent.map((each) => each.mode), everyElement(Mode.agent), reason: 'every agent starts attended');
  expect(sent.map((each) => each.prompt), everyElement(isNull), reason: 'an attended agent is given no prompt');
  expect(World.backend.startedNow, everyElement(isTrue), reason: 'a build must not hold the next start');
}
