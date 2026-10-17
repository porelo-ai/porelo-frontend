import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the key of {'build'} is still there
Future<void> theKeyOfIsStillThere(WidgetTester tester, String name) async {
  expect(File('${World.machines.setup.sshDirectory}/porelo-$name-agent').existsSync(), isTrue);
}
