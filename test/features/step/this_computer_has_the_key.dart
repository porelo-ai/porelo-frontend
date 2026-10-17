import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: this computer has the key {'id_work'}
Future<void> thisComputerHasTheKey(WidgetTester tester, String name) async {
  final ssh = Directory('${World.setup.home.path}/.ssh')..createSync(recursive: true);
  File('${ssh.path}/$name')
      .writeAsStringSync('-----BEGIN OPENSSH PRIVATE KEY-----\nnot a real key\n-----END OPENSSH PRIVATE KEY-----\n');
  File('${ssh.path}/$name.pub').writeAsStringSync('ssh-ed25519 AAAA not-a-real-key\n');
}
