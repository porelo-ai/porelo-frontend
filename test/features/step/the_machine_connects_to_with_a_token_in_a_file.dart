import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine connects to {'https://gitlab.example/acme/'} with a token in a file
Future<void> theMachineConnectsToWithATokenInAFile(WidgetTester tester, String match) async {
  World.backend.theConnections = <Connection>[
    ...World.backend.theConnections,
    Connection(
      id: '/home/agent/.gitlab-token',
      kind: 'TOKEN',
      match: match,
      purpose: 'git',
      source: 'FILE',
      present: true,
    ),
  ];
}
