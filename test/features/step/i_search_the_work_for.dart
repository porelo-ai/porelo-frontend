import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I search the work for {'billing'}
Future<void> iSearchTheWorkFor(WidgetTester tester, String words) async {
  await tester.enterText(find.byKey(const ValueKey<String>('work-list-filter')), words);
  await World.settle(tester);
}
