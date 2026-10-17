import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: ssh config reaches {'porelo-the-build-machine'} as {'agent'} with {'porelo-the-build-machine'}
Future<void> sshConfigReachesAsWith(WidgetTester tester, String alias, String user, String key) async {
  final config = '${World.setup.home.path}/.ssh/config';
  final text = File(config).readAsStringSync();
  expect(text, contains('Host $alias\n    HostName 203.0.113.10\n    User $user\n'));
  expect(text, contains('IdentityFile ${World.setup.home.path}/.ssh/$key\n'));
  expect(text, isNot(contains('User root')));
  expect(FileStat.statSync(config).mode & 0x1FF, 0x180, reason: '~/.ssh/config is not 600');
}
