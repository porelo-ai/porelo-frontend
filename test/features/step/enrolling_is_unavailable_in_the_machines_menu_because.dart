import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: enrolling is unavailable in the machine's menu because {'the vault is shut'}
Future<void> enrollingIsUnavailableInTheMachinesMenuBecause(WidgetTester tester, String reason) async {
  await tester.tap(find.byKey(const Key('machine-menu')).first);
  await World.settle(tester);
  final item = find.ancestor(
    of: find.text('Enroll this device on this machine'),
    matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
  );
  expect(item, findsOneWidget);
  expect(tester.widget<PopupMenuItem<Object?>>(item).enabled, isFalse);
  expect(find.descendant(of: item, matching: find.textContaining(reason)), findsOneWidget);
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await World.settle(tester);
}
