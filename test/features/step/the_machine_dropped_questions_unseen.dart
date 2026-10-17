import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine dropped {2} questions unseen
///
/// What the machine sends when the stream was read too slowly: how many it dropped, asking nothing.
Future<void> theMachineDroppedQuestionsUnseen(WidgetTester tester, int count) async {
  World.backend.asking.add(
    Prompt(task: '', key: '', destination: '', protocol: '', port: 0, at: '', prefix: '', missed: count),
  );
  await World.settle(tester);
}
