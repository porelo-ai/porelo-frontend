import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the task {'porelo-default-fix'} of default works on {'foo-2'}
Future<void> theTaskOfDefaultWorksOn(WidgetTester tester, String task, String repository) async {
  World.backend.publish(<Task>[
    ...World.backend.tasksNow,
    Task.from(<String, dynamic>{
      'name': task,
      'project': defaultProject,
      'repository': repository,
      'securityClass': 'guarded',
      'state': 'Up 1 minute',
      'running': true,
      'helpers': 0,
    }),
  ]);
  await World.settle(tester);
}
