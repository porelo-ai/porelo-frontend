import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the work {'porelo-checkout-shell'} runs {'an-agent'} brokered to {'github-copilot'}
Future<void> theWorkRunsBrokeredTo(WidgetTester tester, String work, String agent, String provider) async {
  World.backend.publish(<Task>[
    for (final each in World.backend.tasksNow)
      each.name != work
          ? each
          : Task(
              name: each.name,
              label: each.label,
              project: each.project,
              securityClass: each.securityClass,
              state: each.state,
              running: each.running,
              helpers: each.helpers,
              agent: agent,
              provider: provider,
              mode: each.mode,
              repository: each.repository,
            ),
  ]);
  await World.settle(tester);
}
