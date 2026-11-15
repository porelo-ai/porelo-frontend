import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine cannot list the models of {'an-agent'}
Future<void> theMachineCannotListTheModelsOf(WidgetTester tester, String agent) async {
  // As Porelo answers when the provider refuses the listing, say for a sign-in by subscription: the agent has a
  // provider, and its model list is refused.
  final backend = World.backend;
  backend
    ..theAgentsItHas = [
      for (final each in backend.theAgentsItHas)
        each.name == agent
            ? Agent.from({
                'name': each.name,
                'label': each.label,
                'binary': each.binary,
                'version': each.version,
                'from': each.from,
                'allowedDomains': each.allowedDomains,
                'found': 'SIGNED_IN',
                'foundProvider': 'anthropic',
              })
            : each,
    ]
    ..offeredModelsFail = VarlinkException('org.fuin.porelo.Tasks1.ModelsFailed', const <String, dynamic>{
      'provider': 'anthropic',
      'reason': 'the provider refuses to list models for this sign-in',
    });
}
