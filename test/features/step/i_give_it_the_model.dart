import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I give it the model {'big-model'}
Future<void> iGiveItTheModel(WidgetTester tester, String model) async {
  await tester.enterText(find.byKey(const Key('start-model')), model);
  await World.settle(tester);
}
