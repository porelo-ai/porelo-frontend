import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine has the key {'/home/me/.ssh/id_ed25519'}
Future<void> theMachineHasTheKey(WidgetTester tester, String path) async {
  World.backend.keysOnTheMachine = <SshKey>[
    ...?World.backend.keysOnTheMachine,
    SshKey(
        path: path,
        type: 'ssh-ed25519',
        fingerprint: 'SHA256:q3Xh0mZ7cK2bY9pWfL1eR4tU8vN6sA5dG0jH3iK7oP2',
        comment: 'me@laptop',
        privateHalf: true,
        usable: true,
        found: 'DIRECTORY'),
  ];
}
