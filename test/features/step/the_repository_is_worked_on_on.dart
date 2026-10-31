import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the repository {'acme/api'} is worked on on {'vm'}
Future<void> theRepositoryIsWorkedOnOn(WidgetTester tester, String repository, String machines) async {
  final row = find.byKey(ValueKey<String>('forge-repository $repository'));
  // The machines' names on its row, and nothing else (walk 10).
  final names = machines.split(',').map((each) => each.trim()).join(', ');
  expect(find.descendant(of: row, matching: find.textContaining('followed on $names ·')), findsOneWidget);
}
