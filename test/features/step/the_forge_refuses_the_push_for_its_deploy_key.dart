import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the forge refuses the push for its deploy key
///
/// As Porelo answers it: the key ssh was given is one the forge knows as a deploy key without the right
/// to push; the account has that key and another in its ssh-agent, and one in its ssh folder.
Future<void> theForgeRefusesThePushForItsDeployKey(WidgetTester tester) async {
  const address = 'ssh://git@github.com/acme/money.git';
  World.backend
    ..refuseTheKeyFor = address
    ..theKeyRefusal = const <String, dynamic>{
      'outcome': 'PUSH_REFUSED',
      'address': address,
      'source': 'AGENT',
      'id': 'SHA256:deployKeyOfTheRepository',
      'fingerprint': 'SHA256:deployKeyOfTheRepository',
      'forge': 'DEPLOY_KEY',
      'command': <String>['porelo', 'credentials', 'keys'],
      'message': 'The push was refused. Run: porelo credentials keys',
    }
    ..keysOnTheMachine = const <SshKey>[
      SshKey(
        path: '',
        type: 'ssh-ed25519',
        fingerprint: 'SHA256:deployKeyOfTheRepository',
        comment: 'deploy money',
        usable: true,
        found: 'AGENT',
        publicKey: 'ssh-ed25519 AAAAdeploy deploy money',
      ),
      SshKey(
        path: '',
        type: 'ssh-ed25519',
        fingerprint: 'SHA256:personalKeyOfThePerson',
        comment: 'alice@laptop',
        usable: true,
        found: 'AGENT',
        publicKey: 'ssh-ed25519 AAAApersonal alice@laptop',
      ),
      SshKey(
        path: '/home/alice/.ssh/id_rsa',
        type: 'ssh-rsa',
        fingerprint: 'SHA256:fileKeyOfThePerson',
        comment: 'alice@old',
        privateHalf: true,
        usable: true,
        found: 'DIRECTORY',
      ),
    ];
}
