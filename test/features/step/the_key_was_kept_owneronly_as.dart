import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the key was kept owner-only as {'porelo-the-build-machine'}
Future<void> theKeyWasKeptOwneronlyAs(WidgetTester tester, String name) async {
  final path = '${World.setup.home.path}/.ssh/$name';
  expect(File(path).existsSync(), isTrue, reason: 'no private key at $path');
  expect(FileStat.statSync(path).mode & 0x1FF, 0x180, reason: 'the private key is not 600');
  expect(File('$path.pub').readAsStringSync(), startsWith('ssh-ed25519 '));
}
