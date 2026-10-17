import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the ssh config no longer has the Host {'porelo-build'}
Future<void> theSshConfigNoLongerHasTheHost(WidgetTester tester, String alias) async {
  final config = File('${World.machines.setup.sshDirectory}/config').readAsStringSync();
  expect(config, isNot(contains('Host $alias\n')));
  expect(config, contains('Host kept\n'), reason: 'only the entry the wizard wrote goes');
}
