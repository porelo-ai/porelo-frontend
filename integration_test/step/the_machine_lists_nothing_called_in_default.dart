import 'package:flutter_test/flutter_test.dart';

import '../support/remote.dart';

/// Usage: the machine lists nothing called {'e2e-default'} in default
Future<void> theMachineListsNothingCalledInDefault(WidgetTester tester, String name) async {
  final listed = await onTheTestMachine('PATH="\$HOME/.local/bin:\$PATH"; porelo project default list');
  expect(listed.split('\n').where((line) => line.startsWith('$name ')), isEmpty, reason: listed);
}
