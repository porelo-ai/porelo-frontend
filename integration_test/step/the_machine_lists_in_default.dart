import 'package:flutter_test/flutter_test.dart';

import '../support/remote.dart';

/// Usage: the machine lists {'e2e-default'} in default
Future<void> theMachineListsInDefault(WidgetTester tester, String name) async {
  final listed = await onTheTestMachine('PATH="\$HOME/.local/bin:\$PATH"; porelo project default list');
  expect(listed.split('\n').where((line) => line.startsWith('$name ')), hasLength(1), reason: listed);
}
