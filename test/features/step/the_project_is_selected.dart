import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: the project {'checkout'} is selected
Future<void> theProjectIsSelected(WidgetTester tester, String project) async {
  await lookingAtTheProjects(tester, () async {
    expect(find.ancestor(of: find.text(project), matching: find.byKey(const Key('selected-row'))), findsOneWidget);
  });
}
