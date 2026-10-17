import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine asks for a decision on {'https://auth.example.com/device'} with the code {'WDJB-MJHT'}
Future<void> theMachineAsksForADecisionOnWithTheCode(WidgetTester tester, String link, String code) async {
  World.backend.granting.add(AuthorizeProgress(state: 'needed', link: link, code: code, expiresIn: 900));
  await World.settle(tester);
}
