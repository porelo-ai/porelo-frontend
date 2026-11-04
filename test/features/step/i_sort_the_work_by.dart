import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I sort the work by {'Sorted by name'}
Future<void> iSortTheWorkBy(WidgetTester tester, String order) async {
  await tester.tap(find.byKey(const ValueKey<String>('work-list-sort')));
  await World.settle(tester);
  await tester.tap(find.byKey(ValueKey<String>('work-list-sort $order')));
  await World.settle(tester);
}
