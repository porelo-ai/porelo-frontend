import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I sign in to {'an-agent'} from the start of the agents
Future<void> iSignInToFromTheStartOfTheAgents(WidgetTester tester, String agent) async {
  final button = find.byKey(ValueKey<String>('start-agents-sign-in $agent'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await World.settle(tester);
}
