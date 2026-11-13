import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the project's repositories are {'utils4j, units4j'}
Future<void> theProjectsRepositoriesAre(WidgetTester tester, String names) async {
  final expected = names.split(',').map((each) => each.trim()).toSet();
  final section = find.byKey(const Key('project-repositories'));
  expect(section, findsOneWidget);
  final rows = <String>{
    for (final element in find.descendant(of: section, matching: find.byType(ListTile)).evaluate())
      if (element.widget.key case ValueKey<String>(:final value) when value.startsWith('repository-'))
        value.substring('repository-'.length),
  };
  expect(rows, expected);
}
