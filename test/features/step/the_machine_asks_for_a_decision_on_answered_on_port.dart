import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine asks for a decision on {'https://forge.example/authorize'} answered on port {'8765'}
Future<void> theMachineAsksForADecisionOnAnsweredOnPort(WidgetTester tester, String link, String port) async {
  World.backend.granting.add(AuthorizeProgress(state: 'needed', link: link, port: int.parse(port), expiresIn: 600));
  await World.settle(tester);
}
