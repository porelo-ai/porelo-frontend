import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I open the machine dialog
Future<void> iOpenTheMachineDialog(WidgetTester tester) async {
  final button = find.byKey(const Key('watch-another-machine'));
  if (button.evaluate().isEmpty) {
    await tester.tap(find.byKey(const Key('bar-overflow')));
    await World.settle(tester);
    await tester.tap(find.text('Watch another machine…'));
  } else {
    await tester.tap(button);
  }
  await World.settle(tester);
}
