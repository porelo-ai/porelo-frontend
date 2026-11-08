import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/page_explanation.dart';
import 'package:porelo_frontend/src/ui/window_size.dart';

import '../support/world.dart';

/// Usage: Running keeps its tabs under the Work head
Future<void> runningKeepsItsTabsUnderTheWorkHead(WidgetTester tester) async {
  final head = find.byType(PageHead);
  expect(head, findsOneWidget);
  final shown = tester.widget<PageHead>(head);
  expect(shown.title, 'Work');
  expect(shown.subtitle, isNotEmpty, reason: 'Work keeps its total while a terminal is shown');
  expect(find.descendant(of: head, matching: find.byKey(const Key('new-work'))), findsOneWidget);
  final switcher = find.byKey(const Key('work-view'));
  final tabs = find.byKey(const Key('running-tabs'));
  expect(switcher, findsOneWidget);
  expect(tabs, findsOneWidget);
  expect(tester.getBottomLeft(head).dy, lessThanOrEqualTo(tester.getTopLeft(switcher).dy));
  expect(tester.getBottomLeft(switcher).dy, lessThanOrEqualTo(tester.getTopLeft(tabs).dy));
  if (WindowSize.fromContext(tester.element(head)) == WindowSize.compact) {
    expect(tester.getSize(switcher).width, tester.getSize(find.byKey(const Key('new-work'))).width);
  }
  expect(find.byKey(const Key('terminal')).hitTestable(), findsOneWidget);
  expect(find.byType(TextField), findsNothing);
  expect(find.byKey(const Key('work-list-sort')), findsNothing);
  expect(tester.takeException(), isNull);

  final task = World.sessions.current?.task;
  await tester.tap(find.byKey(const Key('work-view-list')));
  await World.settle(tester);
  expect(find.descendant(of: head, matching: find.byKey(const Key('work-list-filter'))), findsOneWidget);
  expect(find.descendant(of: head, matching: find.byKey(const Key('work-list-sort'))), findsOneWidget);
  await tester.ensureVisible(find.byKey(const Key('work-view-running')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('work-view-running')));
  await World.settle(tester);
  expect(World.sessions.current?.task, task);
  expect(find.byKey(const Key('terminal')).hitTestable(), findsOneWidget);
  expect(find.byType(TextField), findsNothing);
  expect(find.byKey(const Key('work-list-sort')), findsNothing);
  expect(tester.takeException(), isNull);
}
