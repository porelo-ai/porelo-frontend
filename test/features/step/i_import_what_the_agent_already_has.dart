import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I import what the agent already has
Future<void> iImportWhatTheAgentAlreadyHas(WidgetTester tester) async {
  final action = find.byKey(const Key('import-credential')).first;
  await tester.ensureVisible(action);
  await tester.pump();
  await tester.tap(action);
  await World.settle(tester);
}
