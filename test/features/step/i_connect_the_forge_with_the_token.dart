import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';
import '../support/forge_prompt.dart';

/// Usage: I connect the forge with the token {'ghp_accepted'}
Future<void> iConnectTheForgeWithTheToken(WidgetTester tester, String token) async {
  await tester.tap(find.byKey(const Key('forge-add')));
  await World.settle(tester);
  await answerForgePrompt(tester, token);
  await openTheForgeShown(tester);
  await World.settle(tester);
}
