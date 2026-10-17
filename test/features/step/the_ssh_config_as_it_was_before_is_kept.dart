import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the ssh config as it was before is kept
Future<void> theSshConfigAsItWasBeforeIsKept(WidgetTester tester) async {
  final ssh = World.machines.setup.sshDirectory;
  final kept = Directory(ssh).listSync().whereType<File>().where((file) => file.path.contains('before-forgetting'));
  expect(kept, hasLength(1));
  expect(kept.single.readAsStringSync(), contains('Host porelo-'));
}
