import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: I choose no project for it
Future<void> iChooseNoProjectForIt(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('new-work-in $defaultProject')));
  await World.settle(tester);
}
