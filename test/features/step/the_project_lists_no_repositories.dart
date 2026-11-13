import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the project lists no repositories
Future<void> theProjectListsNoRepositories(WidgetTester tester) async {
  expect(find.byKey(const Key('project-repositories')), findsNothing);
  expect(find.byKey(const Key('project-repositories-not-carried')), findsNothing);
  expect(find.byKey(const Key('repository-default')), findsNothing);
}
