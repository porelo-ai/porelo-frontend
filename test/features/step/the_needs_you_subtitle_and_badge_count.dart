import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/expandable_list_row.dart';
import 'package:porelo_frontend/src/ui/page_explanation.dart';

/// Usage: the Needs you subtitle and badge count {1}
Future<void> theNeedsYouSubtitleAndBadgeCount(WidgetTester tester, int count) async {
  final head = find.byType(PageHead);
  expect(head, findsOneWidget);
  expect(tester.widget<PageHead>(head).title, 'Needs you');
  final subtitle = find.byKey(const Key('needs-you-subtitle'));
  expect(find.descendant(of: head, matching: subtitle), findsOneWidget);
  expect(tester.widget<Text>(subtitle).data, count == 0 ? 'Nothing waits on you' : '$count need you');
  final badge = tester.widget<Badge>(find.byKey(const Key('needing-count-badge')));
  expect(badge.isLabelVisible, count != 0);
  if (count != 0) expect((badge.label! as Text).data, '$count');
  expect(
    find.descendant(of: find.byKey(const Key('open-attention')), matching: find.byType(ExpandableListRow)),
    findsNWidgets(count),
    reason: 'every waiting row counts; recently resolved rows do not',
  );
}
