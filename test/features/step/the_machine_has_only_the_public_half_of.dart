import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine has only the public half of {'/home/me/.ssh/company_key'}
Future<void> theMachineHasOnlyThePublicHalfOf(WidgetTester tester, String path) async {
  World.backend.keysOnTheMachine = <SshKey>[
    ...?World.backend.keysOnTheMachine,
    SshKey(
      path: path,
      type: 'ssh-ed25519',
      fingerprint: 'SHA256:MNa4pQ7rS0tU3vW6xY9zA2bC5dE8fG1hI4jK7lM0nO3',
      comment: 'company@forge',
      found: 'DIRECTORY',
      obstacle: 'only the public half is here; the private key is what a machine signs with',
    ),
  ];
}
