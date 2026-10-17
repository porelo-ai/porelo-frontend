import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the work {'porelo-checkout-shell'} works in the repository {'payments-api'}
Future<void> theWorkWorksInTheRepository(WidgetTester tester, String work, String repository) async {
  World.backend.publish(<Task>[
    for (final task in World.backend.tasksNow)
      task.name == work ? Task.from(<String, dynamic>{...wire(task), 'repository': repository}) : task,
  ]);
  await World.settle(tester);
}
