import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';
import 'the_stores_lock_says.dart';

/// Usage: I shut the store
Future<void> iShutTheStore(WidgetTester tester) async {
  // The lock on the machine's page; the answer stays in the dialog until it is closed.
  await toTheLock(tester);
  await tester.tap(find.byKey(const Key('vault-act')));
  await World.settle(tester);
  await tester.tap(find.byKey(const Key('vault-confirm')));
  await World.settle(tester);
}
