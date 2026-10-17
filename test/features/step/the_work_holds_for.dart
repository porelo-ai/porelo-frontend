import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the work {'porelo-checkout-migrate'} holds {'a-provider'} for {'weather'}
Future<void> theWorkHoldsFor(WidgetTester tester, String work, String entry, String destination) async {
  World.backend.publish(<Task>[
    for (final task in World.backend.tasksNow)
      task.name == work
          ? Task.from(<String, dynamic>{...wire(task), 'credentials': <String, dynamic>{entry: destination}})
          : task,
  ]);
  await World.settle(tester);
}
