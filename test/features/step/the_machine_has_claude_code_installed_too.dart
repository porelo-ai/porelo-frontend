import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine has Claude Code installed too
Future<void> theMachineHasClaudeCodeInstalledToo(WidgetTester tester) async {
  World.backend.theAgentsItHas = <Agent>[
    ...World.backend.theAgentsItHas,
    Agent.from(const <String, dynamic>{
      'name': 'claude',
      'label': 'Claude Code',
      'binary': '/usr/bin/claude',
      'version': '2.1.267',
      'from': '/usr/libexec/porelo/agents/porelo-agent-claude',
    }),
  ];
}
