import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I search the work for {'billing'}
Future<void> iSearchTheWorkFor(WidgetTester tester, String words) async {
  final field = find.byKey(const ValueKey<String>('work-list-filter'));
  if (field.evaluate().isEmpty) {
    await tester.tap(find.byKey(const ValueKey<String>('work-list-search')));
    await World.settle(tester);
  }
  await tester.enterText(field, words);
  await World.settle(tester);
}
