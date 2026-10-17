import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: the card of {'checkout'} is not marked unverified
Future<void> theCardOfIsNotMarkedUnverified(WidgetTester tester, String project) async {
  await lookingAtTheProjects(tester, () async {
    expect(cardFor(project), findsOneWidget);
    expect(find.descendant(of: cardFor(project), matching: find.byKey(const Key('project-unverified'))), findsNothing);
  });
}
