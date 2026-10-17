import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the first link offered says {'Sign in: the reply comes back here'}, and opens {'https://…'}
Future<void> theFirstLinkOfferedSaysAndOpens(WidgetTester tester, String words, String address) async {
  final offered = find.byWidgetPredicate(
    (each) => each.key is ValueKey<String> && (each.key! as ValueKey<String>).value.startsWith('terminal-link '),
  );
  final first = offered.evaluate().map((each) => each.widget.key! as ValueKey<String>).toList()
    ..sort((a, b) {
      final ra = tester.getRect(find.byKey(a));
      final rb = tester.getRect(find.byKey(b));
      return ra.top != rb.top ? ra.top.compareTo(rb.top) : ra.left.compareTo(rb.left);
    });
  expect(first.first.value, 'terminal-link $address');
  expect(find.descendant(of: find.byKey(first.first), matching: find.text(words)), findsOneWidget);
}
