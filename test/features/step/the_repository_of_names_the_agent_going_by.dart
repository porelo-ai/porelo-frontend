import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the repository {'ledger'} of {'checkout'} names the agent {'other-agent'} going by {'Agent ledger'}
///
/// As a Porelo that knows a repository's agent answers: every other repository of the project says
/// it names none, the project's own repository among them.
Future<void> theRepositoryOfNamesTheAgentGoingBy(
  WidgetTester tester,
  String repository,
  String project,
  String agent,
  String goesBy,
) async {
  World.backend.answerRepositories((of, each) {
    if (of.name != project) return each;
    final named = each.name == repository;
    return Repository(
      name: each.name,
      own: each.own,
      upstream: each.upstream,
      mirror: each.mirror,
      pending: each.pending,
      behind: each.behind,
      behindMeasured: each.behindMeasured,
      behindReason: each.behindReason,
      behindDetail: each.behindDetail,
      limits: each.limits,
      agent: named ? agent : (each.agent ?? ''),
      goesBy: named ? goesBy : (each.agent == null ? 'Agent ${each.name}' : each.goesBy),
    );
  });
  await World.machines.fleet.refresh(quietly: true);
  await World.settle(tester);
}
