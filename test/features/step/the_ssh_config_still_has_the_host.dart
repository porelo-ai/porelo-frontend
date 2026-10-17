import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the ssh config still has the Host {'porelo-build'}
Future<void> theSshConfigStillHasTheHost(WidgetTester tester, String alias) async {
  final config = File('${World.machines.setup.sshDirectory}/config').readAsStringSync();
  expect(config, contains('Host $alias\n'));
}
