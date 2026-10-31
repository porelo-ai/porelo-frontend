import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';
import '../support/forge_prompt.dart';
import '../../support/expand_list_rows.dart';

/// Usage: I change {'GitHub'} to be called {'GitHub private'} with the token {'ghp_renewed'}
Future<void> iChangeToBeCalledWithTheToken(WidgetTester tester, String name, String renamed, String token) async {
  await expandListRows(tester);
  await World.settle(tester);
  // A new token is the forge's explicit alternative in its menu on the Forges page, or a form
  // already open (a binding asks for it in place).
  if (find.byKey(const Key('forge-name')).evaluate().isEmpty) {
    await tester.tap(find.byKey(ValueKey<String>('forges-menu $name')).first);
    await World.settle(tester);
    await tester.tap(find.byKey(const ValueKey<String>('forge.useToken')).last);
    await World.settle(tester);
  }
  await tester.enterText(find.byKey(const Key('forge-name')), renamed);

  await World.settle(tester);
  await answerForgePrompt(tester, token);
  await World.settle(tester);
}
