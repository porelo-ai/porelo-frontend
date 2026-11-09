import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the repository {'billing'} cannot be started from its row
Future<void> theRepositoryCannotBeStartedFromItsRow(WidgetTester tester, String repository) async {
  final row = find.byKey(Key('repository-$repository'));
  expect(row, findsOneWidget);
  expect(tester.widget<ListTile>(row).onTap, isNull, reason: 'a tap on $repository starts work there');
}
