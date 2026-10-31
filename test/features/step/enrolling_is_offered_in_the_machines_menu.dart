import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';
import 'the_stores_lock_says.dart';

/// Usage: enrolling is offered in the machine's menu
Future<void> enrollingIsOfferedInTheMachinesMenu(WidgetTester tester) async {
  // The menu on top of the machine's own page, where its lock is too.
  await toTheLock(tester);
  await tester.tap(find.byKey(const Key('machine-menu')).first);
  await World.settle(tester);
  final item = find.ancestor(
    of: find.text('Enroll this device on this machine'),
    matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
  );
  expect(item, findsOneWidget);
  expect(tester.widget<PopupMenuItem<Object?>>(item).enabled, isTrue);
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await World.settle(tester);
}
