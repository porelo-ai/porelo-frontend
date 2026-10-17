import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the work {'porelo-checkout-shell'} was handed {'verdict.json'} by Porelo
Future<void> theWorkWasHandedByPorelo(WidgetTester tester, String work, String name) async {
  World.backend.publish(<Task>[
    for (final task in World.backend.tasksNow)
      if (task.name == work)
        FakeBackend.withHandIn(task, files: <HandedFile>[
          HandedFile(name: name, bytes: 120, sha256: 'ab' * 32, by: HandedFile.porelo, run: task.run ?? ''),
        ])
      else
        task,
  ]);
  await World.settle(tester);
}
