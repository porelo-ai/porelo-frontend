import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the repository {'ledger'} of {'checkout'} runs {'big-model'} by default for {'a-provider'}
Future<void> theRepositoryOfRunsByDefaultFor(
  WidgetTester tester,
  String repository,
  String project,
  String model,
  String provider,
) async {
  World.backend.answerRepositories((of, each) {
    if (of.name != project || each.name != repository) return each;
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
      agent: each.agent,
      nickname: each.nickname,
      goesBy: each.goesBy,
      defaultModels: <ProviderModel>[ProviderModel(provider: provider, model: model, from: 'repository')],
    );
  });
  await World.machines.fleet.refresh(quietly: true);
  await World.settle(tester);
}
