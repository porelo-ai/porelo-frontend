import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine keeps the deploy key {'porelo vm default/foo-2'} for {'foo-2'} in default
Future<void> theMachineKeepsTheDeployKeyForInDefault(WidgetTester tester, String title, String repository) async {
  World.backend.deployKeysMade.add(
    MachineDeployKey(
      entry: 'deploy/$defaultProject/$repository',
      repository: repository,
      upstream: '',
      publicKey: 'ssh-ed25519 AAAA porelo@vm',
      fingerprint: 'SHA256:kept',
      title: title,
      writeAccess: true,
      made: false,
    ),
  );
}
