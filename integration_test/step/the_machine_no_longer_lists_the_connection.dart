import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/machines.dart';

import '../support/e2e.dart';

/// Usage: the machine no longer lists the connection {'https://e2e.invalid/'}
Future<void> theMachineNoLongerListsTheConnection(WidgetTester tester, String match) async {
  final client = await PoreloClient.connect(
      Backend(socketPath: Machine.endpointFor(E2e.name), label: E2e.name));
  expect((await client.credentials()).connections.map((each) => each.match), isNot(contains(match)));
}
