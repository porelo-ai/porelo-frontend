import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/expand_list_rows.dart';

/// Usage: what needs a person names the project {'checkout'}
Future<void> whatNeedsAPersonNamesTheProject(WidgetTester tester, String project) async {
  await expandListRows(tester);
  expect(notFollowing(project), findsOneWidget);
}

/// The notice for [project] under what needs a person, on whichever machine.
Finder notFollowing(String project) => find.byWidgetPredicate((widget) {
  final key = widget.key;
  return key is ValueKey<String> && key.value.startsWith('not-following ') && key.value.endsWith('/$project');
});
