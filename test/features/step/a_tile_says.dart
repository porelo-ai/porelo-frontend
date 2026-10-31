import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';

/// Usage: a tile says {'Cannot be reached'}
Future<void> aTileSays(WidgetTester tester, String words) async {
  // A row is opened by a click on it, and the opened work covers the list: it is closed to read the
  // rows again, as a person does, and the work page gone to where the window is elsewhere.
  if (workRows().evaluate().isEmpty && find.byTooltip('Close (Esc)').evaluate().isNotEmpty) {
    await tester.tap(find.byTooltip('Close (Esc)').first);
    await World.settle(tester);
  }
  if (workRows().evaluate().isEmpty) await toThePlace(tester, 'work');
  Finder said() => find.descendant(of: workRows(), matching: find.textContaining(words));
  if (said().evaluate().isEmpty) {
    // A folded row shows its work, its machine and its mark; it is unfolded for the rest.
    for (final row in workRows().evaluate().toList()) {
      final it = find.byWidget(row.widget);
      final fold = find.descendant(
        of: it,
        matching: find.byWidgetPredicate((widget) => '${widget.key}'.startsWith("[<'tile-fold ")),
      );
      if (fold.evaluate().isEmpty) continue;
      if (find.descendant(of: it, matching: find.byKey(const Key('tile-headline'))).evaluate().isNotEmpty) continue;
      await tester.ensureVisible(fold.first);
      await tester.tap(fold.first);
      await tester.pump();
    }
  }
  expect(said(), findsWidgets);
}
