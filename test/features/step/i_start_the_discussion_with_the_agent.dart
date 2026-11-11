import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I start the discussion with the agent {agent}
Future<void> iStartTheDiscussionWithTheAgent(WidgetTester tester, String agent) async {
  await tester.tap(find.byKey(const Key('discussion-agent')));
  await World.settle(tester);
  await tester.tap(find.byKey(ValueKey<String>('start-agent-choice $agent')).last);
  await World.settle(tester);
  await tester.tap(find.byKey(const Key('discussion-start')));
  await World.settle(tester);
}
