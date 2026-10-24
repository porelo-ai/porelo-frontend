import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';
import '../support/forge_prompt.dart';

/// Usage: I add the forge {'GitHub work'} at {'github.com'} with the token {'ghp_work'}
Future<void> iAddTheForgeAtWithTheToken(WidgetTester tester, String name, String address, String token) async {
  await tester.tap(find.byKey(const Key('forge-add')));
  await World.settle(tester);
  await tester.enterText(find.byKey(const Key('forge-name')), name);
  await tester.enterText(find.byKey(const Key('forge-address')), address);

  await World.settle(tester);
  await answerForgePrompt(tester, token);
  await World.settle(tester);
}
