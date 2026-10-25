import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/expandable_list_row.dart';

/// Opens local details through disclosure before a step reads or acts within them.
Future<void> expandListRows(WidgetTester tester, {Finder? within}) async {
  final rows = within == null
      ? find.byType(ExpandableListRow)
      : find.descendant(of: within, matching: find.byType(ExpandableListRow), matchRoot: true);
  final arrows = find.descendant(
    of: rows,
    matching: find.byWidgetPredicate((widget) => widget is IconButton && widget.tooltip == 'Show more'),
  );
  for (final element in arrows.evaluate().toList()) {
    final arrow = find.byWidget(element.widget);
    await tester.ensureVisible(arrow);
    await tester.tap(arrow);
    await tester.pump();
  }
  if (rows.evaluate().isNotEmpty) await tester.ensureVisible(rows.first);
}
