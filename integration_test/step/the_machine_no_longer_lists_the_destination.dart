import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/machines.dart';

import '../support/e2e.dart';

/// Usage: the machine no longer lists the destination {'e2e-weather'}
Future<void> theMachineNoLongerListsTheDestination(WidgetTester tester, String name) async {
  final client = await PoreloClient.connect(
      Backend(socketPath: Machine.endpointFor(E2e.name), label: E2e.name));
  expect((await client.destinations()).map((each) => each.name), isNot(contains(name)));
}
