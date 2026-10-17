import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/machines.dart';

import '../support/world.dart';

/// Usage: the machine {'handmade'} is reached through a Host entry written by hand
Future<void> theMachineIsReachedThroughAHostEntryWrittenByHand(WidgetTester tester, String name) async {
  final ssh = World.machines.setup.sshDirectory;
  Directory(ssh).createSync(recursive: true);
  File('$ssh/config').writeAsStringSync('Host $name\n    HostName $name.example.test\n    User me\n');
  await World.machines.add(Machine(
    name: name,
    socketPath: Machine.endpointFor(name),
    host: name,
    remoteSocket: '/run/user/1000/porelo/porelod.sock',
  ));
  await World.settle(tester);
}
