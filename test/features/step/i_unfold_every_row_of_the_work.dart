import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';

/// Usage: I unfold every row of the work
Future<void> iUnfoldEveryRowOfTheWork(WidgetTester tester) async {
  for (final row in workRows().evaluate().toList()) {
    final fold = find.descendant(
      of: find.byWidget(row.widget),
      matching: find.byWidgetPredicate((widget) => '${widget.key}'.startsWith("[<'tile-fold ")),
    );
    if (find
        .descendant(of: find.byWidget(row.widget), matching: find.byKey(const Key('tile-details')))
        .evaluate()
        .isNotEmpty) {
      continue;
    }
    await tester.ensureVisible(fold.first);
    await tester.pump();
    await tester.tap(fold.first);
    await tester.pump();
  }
  await World.settle(tester);
}
