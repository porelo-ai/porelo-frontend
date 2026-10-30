import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/connections.dart';

import '../support/world.dart';

/// Usage: the key was allowed for {'agent'}
Future<void> theKeyWasAllowedFor(WidgetTester tester, String user) async {
  final allowed = World.setup.asRootRan.where((script) => script.contains('authorized_keys'));
  expect(allowed, hasLength(1));
  expect(allowed.single, contains('user=${quoteForAShell(user)}\n'));
  final person = File('${World.setup.home.path}/.ssh/person.pub').readAsStringSync().trim();
  expect(allowed.single, contains('key=${quoteForAShell(person)}\n'));
  // With a key and nothing else.
  expect(allowed.single, contains(r'passwd -l "$user"'));
  expect(allowed.single, contains('AuthenticationMethods publickey'));
}
