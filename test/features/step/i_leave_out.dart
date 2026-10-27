import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I leave out {'payments-api'}
Future<void> iLeaveOut(WidgetTester tester, String repository) async {
  final row = find.byKey(ValueKey<String>('start-agents-row $repository'));
  await tester.ensureVisible(row);
  await tester.tap(row);
  await World.settle(tester);
}
