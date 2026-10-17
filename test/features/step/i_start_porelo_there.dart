import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';

/// Usage: I start Porelo there
Future<void> iStartPoreloThere(WidgetTester tester) async {
  await tapOnScreen(tester, find.byKey(const Key('start-it')));
  await World.settle(tester);
}
