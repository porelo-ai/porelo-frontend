import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';
import '../support/forge_prompt.dart';

/// Usage: I connect the forge with the token {'ghp_accepted'}
Future<void> iConnectTheForgeWithTheToken(WidgetTester tester, String token) async {
  await World.settle(tester);
  await answerForgePrompt(tester, token);
  await openTheForgeShown(tester);
  await World.settle(tester);
}
