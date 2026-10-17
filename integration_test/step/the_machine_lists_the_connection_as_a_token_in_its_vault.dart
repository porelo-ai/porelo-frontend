import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/machines.dart';

import '../support/e2e.dart';
import '../support/remote.dart';

/// Usage: the machine lists the connection {'https://e2e-typed.invalid/'} as a token in its vault
Future<void> theMachineListsTheConnectionAsATokenInItsVault(WidgetTester tester, String match) async {
  final client = await PoreloClient.connect(
      Backend(socketPath: Machine.endpointFor(E2e.name), label: E2e.name));
  Connection? connection;
  final until = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(until)) {
    final store = await client.credentials();
    connection = store.connections.where((each) => each.match == match).firstOrNull;
    if (connection != null && connection.present) break;
    await pumpFor(tester, const Duration(seconds: 1));
  }
  expect(connection, isNotNull, reason: 'the machine lists no connection for $match');
  expect(connection!.kind, 'TOKEN');
  expect(connection.source, 'VAULT');
  expect(connection.present, isTrue, reason: 'what was typed in the terminal did not reach the vault');
  theVaultEntry = connection.id;
}
