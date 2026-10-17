import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: enrolling is offered in the machine's menu
Future<void> enrollingIsOfferedInTheMachinesMenu(WidgetTester tester) async {
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
