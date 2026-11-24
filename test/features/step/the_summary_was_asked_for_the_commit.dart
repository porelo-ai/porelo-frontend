import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the summary was asked for the commit {'9a3c1f2e4b5d6a7c8e9f0a1b2c3d4e5f6a7b8c9d'}
Future<void> theSummaryWasAskedForTheCommit(WidgetTester tester, String commit) async {
  expect(World.backend.summariesAsked, isNotEmpty, reason: 'no summary was asked');
  expect({for (final asked in World.backend.summariesAsked) asked.commit}, <String>{commit});
}
