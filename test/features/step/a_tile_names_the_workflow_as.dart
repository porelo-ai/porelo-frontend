import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'a_tile_says.dart';

/// Usage: a tile names the workflow {'Build'} as {'passed'}
Future<void> aTileNamesTheWorkflowAs(WidgetTester tester, String workflow, String verdict) async {
  // Unfolds the tile the way a person reads it, then reads the workflow's own line.
  await aTileSays(tester, workflow);
  final line = find.byKey(ValueKey<String>('tile-workflow $workflow'));
  expect(line, findsOneWidget);
  expect(find.descendant(of: line, matching: find.text(verdict)), findsOneWidget);
}
