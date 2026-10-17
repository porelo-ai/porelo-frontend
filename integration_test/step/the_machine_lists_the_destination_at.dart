import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/machines.dart';

import '../support/e2e.dart';

/// Usage: the machine lists the destination {'e2e-weather'} at {'https://api.weather.invalid/v1'}
Future<void> theMachineListsTheDestinationAt(WidgetTester tester, String name, String upstream) async {
  final client = await PoreloClient.connect(Backend(socketPath: Machine.endpointFor(E2e.name), label: E2e.name));
  final listed = (await client.destinations()).where((each) => each.name == name).toList();
  expect(listed.map((each) => (each.upstream, each.packaged, each.inForce)), <(String, bool, bool)>[
    (upstream, false, true),
  ]);
  expect(listed.single.keyGoes, 'in the header Authorization, after "Bearer "');
}
