import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/page_explanation.dart';

import '../support/tiles.dart';

/// Usage: the list of work counts {4}
Future<void> theListOfWorkCounts(WidgetTester tester, int count) async {
  expect(find.byType(PageHead), findsOneWidget);
  expect(tester.widget<PageHead>(find.byType(PageHead)).title, 'Work');
  expect(workRows(), findsNWidgets(count));
  final subtitle = find.byKey(const Key('work-list-subtitle'));
  expect(subtitle, findsOneWidget);
  final total = RegExp(r'^(\d+) pieces? of work\b').firstMatch(tester.widget<Text>(subtitle).data ?? '');
  expect(total, isNotNull, reason: 'the subtitle must show the Work total');
  expect(int.parse(total!.group(1)!), count);
}
