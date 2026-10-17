import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: the project {'unrecorded'} is listed
Future<void> theProjectIsListed(WidgetTester tester, String project) async {
  // Never silently omitted: a project nothing can act on is exactly the one somebody needs to see.
  // The tree builds only what is in view, so it is scrolled to the project before looking.
  await lookingAtTheProjects(tester, () async {
    final tree = find.descendant(of: find.byKey(const Key('projects-page')), matching: find.byType(Scrollable));
    if (find.text(project).evaluate().isEmpty && tree.evaluate().isNotEmpty) {
      await tester.scrollUntilVisible(find.text(project), 100, scrollable: tree.first);
    }
    expect(find.text(project), findsWidgets);
  });
}
