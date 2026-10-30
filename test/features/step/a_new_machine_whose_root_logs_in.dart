import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: a new machine whose root logs in
///
/// The wizard walked to its third step: a name, a generated key kept, a host whose root logs in.
Future<void> aNewMachineWhoseRootLogsIn(WidgetTester tester) async {
  Future<void> tap(String key) => World.tapInView(tester, key);

  await tester.enterText(find.byKey(const Key('machine-name')), 'the build machine');
  await World.settle(tester);
  await World.chooseWords(tester, 'A new machine');
  await tap('wizard-next');
  await tap('use-person-identity');
  await tap('setup-next');
  await tester.enterText(find.byKey(const Key('new-host')), '203.0.113.10');
  await World.settle(tester);
  await tap('try-root-login');
  await tap('setup-next');
}
