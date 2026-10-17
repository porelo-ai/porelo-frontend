import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine connects to {'ssh://github.com'} with a key in the vault
Future<void> theMachineConnectsToWithAKeyInTheVault(WidgetTester tester, String match) async {
  World.backend.theConnections = <Connection>[
    ...World.backend.theConnections,
    Connection(
        id: 'git.ssh.github.com', kind: 'SSH_KEY', match: match, purpose: 'git', source: 'VAULT', protected: true),
  ];
}
