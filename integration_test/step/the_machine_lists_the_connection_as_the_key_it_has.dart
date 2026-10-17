import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/machines.dart';

import '../support/e2e.dart';
import '../support/remote.dart';

/// Usage: the machine lists the connection {'ssh://e2e.invalid/'} as the key it has
Future<void> theMachineListsTheConnectionAsTheKeyItHas(WidgetTester tester, String match) async {
  final client = await PoreloClient.connect(Backend(socketPath: Machine.endpointFor(E2e.name), label: E2e.name));
  final store = await client.credentials();
  final connection = store.connections.where((each) => each.match == match).firstOrNull;
  expect(connection, isNotNull, reason: 'connections are ${store.connections.map((each) => each.match).toList()}');
  expect(connection!.kind, 'SSH_KEY');
  expect(connection.source, 'FILE');
  expect(connection.id, theKey, reason: 'the key picked, by its path on the machine');
  expect(connection.present, isTrue, reason: 'it is there, so it is found');
  expect(connection.protected, isFalse, reason: 'where it lies is outside the vault');
}
