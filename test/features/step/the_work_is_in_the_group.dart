import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: the work {'porelo-checkout-shell'} is in the group {'running'}
///
/// `waiting`, `running` or `stopped`: the tile is drawn after that group's heading and before the
/// next one's.
Future<void> theWorkIsInTheGroup(WidgetTester tester, String work, String group) async {
  expect(find.byKey(const Key('work-page')), findsOneWidget, reason: 'the work page is not shown');
  final tile = tileFor(work);
  // The page builds only what is near the screen: scrolled to, as a person would.
  if (tile.evaluate().isEmpty) {
    final page = find.descendant(of: find.byKey(const Key('work-page')), matching: find.byType(Scrollable));
    await tester.scrollUntilVisible(tile, 200, scrollable: page.first, maxScrolls: 30);
  }
  expect(tile, findsOneWidget, reason: '$work is not on the work page');
  final top = tester.getTopLeft(tile).dy;
  final headings = <String, double>{
    for (final name in <String>['waiting', 'running', 'stopped'])
      if (find.byKey(ValueKey<String>('work-group $name')).evaluate().isNotEmpty)
        name: tester.getTopLeft(find.byKey(ValueKey<String>('work-group $name'))).dy,
  };
  expect(headings.containsKey(group), isTrue, reason: 'no group $group is shown');
  final after = headings.entries.where((each) => each.value < top).toList()..sort((a, b) => b.value.compareTo(a.value));
  expect(after.first.key, group, reason: '$work is under ${after.first.key}');
}
