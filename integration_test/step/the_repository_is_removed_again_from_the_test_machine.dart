import 'package:flutter_test/flutter_test.dart';

import '../support/remote.dart';

/// Usage: the repository {'e2e-default'} is removed again from the test machine
Future<void> theRepositoryIsRemovedAgainFromTheTestMachine(WidgetTester tester, String name) async {
  final left = await onTheTestMachine(
    'rm -rf "\$HOME/$name" "\$HOME/$name.git"; ls -d "\$HOME/$name" "\$HOME/$name.git" 2>/dev/null; true',
  );
  expect(left, isEmpty, reason: 'still on the test machine: $left');
}
