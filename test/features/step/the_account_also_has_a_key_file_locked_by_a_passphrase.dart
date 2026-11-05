import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the account also has a key file locked by a passphrase {'/home/alice/.ssh/id_locked'}
///
/// As Porelo lists it: the private file is there, and nothing on the machine can ask for its passphrase.
Future<void> theAccountAlsoHasAKeyFileLockedByAPassphrase(WidgetTester tester, String path) async {
  World.backend.keysOnTheMachine = <SshKey>[
    ...?World.backend.keysOnTheMachine,
    SshKey(
      path: path,
      type: 'ssh-ed25519',
      fingerprint: 'SHA256:lockedKeyOfThePerson',
      privateHalf: true,
      encrypted: true,
      found: 'DIRECTORY',
      obstacle: 'A passphrase protects it, and nothing on the machine can ask for it.',
    ),
  ];
}
