import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/machines.dart';

import '../support/e2e.dart';
import '../support/remote.dart';

/// Usage: the machine lists the connection {'ssh://e2e-vault.invalid/'} as a key in its vault
Future<void> theMachineListsTheConnectionAsAKeyInItsVault(WidgetTester tester, String match) async {
  final client = await PoreloClient.connect(Backend(socketPath: Machine.endpointFor(E2e.name), label: E2e.name));
  // The interface runs the machine's own command to store it; it lands a moment after the record.
  Connection? connection;
  final until = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(until)) {
    final store = await client.credentials();
    connection = store.connections.where((each) => each.match == match).firstOrNull;
    if (connection != null && connection.present) break;
    await pumpFor(tester, const Duration(seconds: 1));
  }
  expect(connection, isNotNull, reason: 'the machine lists no connection for $match');
  expect(connection!.kind, 'SSH_KEY');
  expect(connection.source, 'VAULT');
  expect(connection.protected, isTrue, reason: 'in the vault it is where the machine can shut it');
  expect(connection.present, isTrue, reason: 'the machine read the file into its vault');
  theVaultEntry = connection.id;
  final entry = connection.id;
  removeAfterwards(
    remove: 'porelo vault remove $entry >/dev/null 2>&1 || true',
    leftOver: 'porelo vault list 2>/dev/null | sed "s/^/ENTRY:/"',
    names: <String>['ENTRY:$entry '],
  );
}
