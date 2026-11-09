import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the repository {'ledger'} of {'checkout'} runs {'big-model'} by default for {'a-provider'}
///
/// As the machine answers which model a start that names none runs on.
Future<void> theRepositoryOfRunsByDefaultFor(
  WidgetTester tester,
  String repository,
  String project,
  String model,
  String provider,
) async {
  World.backend.modelsOf = <String, List<ProviderModel>>{
    ...?World.backend.modelsOf,
    '$project/$repository': <ProviderModel>[ProviderModel(provider: provider, model: model, from: 'repository')],
  };
}
