import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: the project {'checkout'} is selected
Future<void> theProjectIsSelected(WidgetTester tester, String project) async {
  await lookingAtTheProjects(tester, () async {
    // Its row on Projects, on the machine being acted on, is the one marked.
    expect(cardFor(project), findsOneWidget, reason: '$project is not listed');
    expect(tester.widget<ListTile>(cardFor(project)).selected, isTrue, reason: '$project is not marked selected');
  });
}
