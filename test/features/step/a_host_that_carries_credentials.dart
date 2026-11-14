import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/machines.dart';

import '../support/carrying.dart';
import '../support/world.dart';

/// Usage: a host {'elsewhere'} that carries credentials
Future<void> aHostThatCarriesCredentials(WidgetTester tester, String name) async {
  // The world reaches a second machine by this name alone.
  expect(name, 'elsewhere');
  final host = CarryingFakeBackend(const <Task>[])..nodeId = 'node-host';
  addTearDown(host.stop);
  World.elsewhere = host;
  await World.machines.add(Machine(name: name, socketPath: '/tmp/world-$name.sock'));
  await World.settle(tester);
}
