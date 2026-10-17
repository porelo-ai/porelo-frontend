import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the appearance is {'dark'}
Future<void> theAppearanceIs(WidgetTester tester, String appearance) async {
  expect(World.themeInUse(tester).brightness, appearance == 'dark' ? Brightness.dark : Brightness.light);
}
