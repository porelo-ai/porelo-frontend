import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the repositories are listed, a card each
Future<void> theRepositoriesAreListedACardEach(WidgetTester tester) async {
  final list = find.byKey(const Key('project-repositories'));
  expect(list, findsOneWidget, reason: 'the repositories are not one list');
  final rows = find.descendant(
    of: list,
    matching: find.byWidgetPredicate(
      (each) =>
          each.key is ValueKey<String> &&
          (each.key! as ValueKey<String>).value.startsWith('repository-') &&
          !(each.key! as ValueKey<String>).value.startsWith('repository-menu '),
    ),
  );
  expect(find.descendant(of: list, matching: find.byType(Card)), findsNWidgets(rows.evaluate().length));
}
