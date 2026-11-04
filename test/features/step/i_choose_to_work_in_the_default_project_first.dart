import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I choose to work in the Default project first
Future<void> iChooseToWorkInTheDefaultProjectFirst(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('first-no-project')));
  await World.settle(tester);
}
