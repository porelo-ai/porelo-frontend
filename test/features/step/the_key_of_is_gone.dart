import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the key of {'build'} is gone
Future<void> theKeyOfIsGone(WidgetTester tester, String name) async {
  final key = '${World.machines.setup.sshDirectory}/porelo-$name-agent';
  expect(File(key).existsSync(), isFalse);
  expect(File('$key.pub').existsSync(), isFalse);
}
