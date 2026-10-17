import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: the card of {'checkout'} is marked unverified
Future<void> theCardOfIsMarkedUnverified(WidgetTester tester, String project) async {
  await lookingAtTheProjects(tester, () async {
    expect(
      find.descendant(of: cardFor(project), matching: find.byKey(const Key('project-unverified'))),
      findsOneWidget,
    );
  });
}
