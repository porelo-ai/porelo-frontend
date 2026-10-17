import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: the project {'checkout'} is not marked as stale
Future<void> theProjectIsNotMarkedAsStale(WidgetTester tester, String project) async {
  await lookingAtTheProjects(tester, () async {
    // A card that is not there has no mark either, which would pass this for the wrong reason.
    expect(cardFor(project), findsOneWidget);
    expect(find.descendant(of: cardFor(project), matching: find.byKey(const Key('project-stale'))), findsNothing);
  });
}
