import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/expandable_list_row.dart';

/// Usage: nothing needs me
Future<void> nothingNeedsMe(WidgetTester tester) async {
  // A zero total hides the badge on every page.
  expect(tester.widget<Badge>(find.byKey(const Key('needing-count-badge'))).isLabelVisible, isFalse);
  final subtitle = find.byKey(const Key('needs-you-subtitle'));
  expect(subtitle, findsOneWidget);
  expect(tester.widget<Text>(subtitle).data, 'Nothing waits on you');
  expect(
    find.descendant(of: find.byKey(const Key('open-attention')), matching: find.byType(ExpandableListRow)),
    findsNothing,
  );
}
