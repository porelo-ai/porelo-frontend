import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: another Host entry uses the key of {'build'}
Future<void> anotherHostEntryUsesTheKeyOf(WidgetTester tester, String name) async {
  final ssh = World.machines.setup.sshDirectory;
  File('$ssh/config').writeAsStringSync(
      '\nHost other\n    HostName other.example.test\n    IdentityFile $ssh/porelo-$name-agent\n',
      mode: FileMode.append);
}
