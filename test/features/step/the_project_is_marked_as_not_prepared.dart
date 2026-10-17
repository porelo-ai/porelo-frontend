import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// How many not-prepared marks a project's card carries.
int marksNotPrepared(WidgetTester tester, String project) => tester
    .widgetList(find.descendant(of: cardFor(project), matching: find.byKey(const Key('project-unprepared'))))
    .length;

/// Usage: the project {'unrecorded'} is marked as not prepared
Future<void> theProjectIsMarkedAsNotPrepared(WidgetTester tester, String project) async {
  await lookingAtTheProjects(tester, () async {
    // The one state that makes an otherwise healthy project unusable, marked on its card.
    expect(marksNotPrepared(tester, project), 1, reason: '$project should be marked as not prepared');
  });
}
