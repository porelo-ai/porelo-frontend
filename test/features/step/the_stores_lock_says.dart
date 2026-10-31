import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';

/// Usage: the store's lock says {'The vault is open. Shut it.'}
Future<void> theStoresLockSays(WidgetTester tester, String words) async {
  // On the page of the machine being acted on, under whatever is open over it.
  await toTheLock(tester);
  final button = find.byKey(const Key('vault-act'));
  expect(button, findsOneWidget);
  expect(
    find.ancestor(of: button, matching: find.byTooltip(words)),
    findsOneWidget,
    reason: 'the lock says something else',
  );
}

/// Brings the lock of the machine being acted on on screen: it stands on that machine's own page.
Future<void> toTheLock(WidgetTester tester) async {
  await closeWhatCoversThePage(tester);
  if (find.byKey(const Key('vault-act')).evaluate().isEmpty) {
    await toTheMachinesPage(tester, World.machines.current.name);
  }
}
