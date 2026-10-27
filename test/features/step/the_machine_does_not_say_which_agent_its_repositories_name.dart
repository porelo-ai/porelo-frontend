import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine does not say which agent its repositories name
Future<void> theMachineDoesNotSayWhichAgentItsRepositoriesName(WidgetTester tester) async {
  World.backend.answerRepositories(
    (_, each) => Repository(
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
    ),
  );
  await World.machines.fleet.refresh(quietly: true);
  await World.settle(tester);
}
