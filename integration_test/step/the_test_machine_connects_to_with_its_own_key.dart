import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/machines.dart';

import '../support/e2e.dart';
import '../support/remote.dart';

/// Usage: the test machine connects to {'ssh://github.com/'} with its own key
Future<void> theTestMachineConnectsToWithItsOwnKey(WidgetTester tester, String match) async {
  // Where it lies, so the check before a follow passes and the follow reaches the host itself.
  final client = await PoreloClient.connect(
      Backend(socketPath: Machine.endpointFor(E2e.name), label: E2e.name));
  await client.credentialDeclare(kind: 'SSH_KEY', match: match, source: 'FILE', id: theKey, purpose: 'git');
}
