import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: work is started elsewhere in {'checkout'}
Future<void> workIsStartedElsewhereIn(WidgetTester tester, String project) async {
  // Somebody else's doing, on the machine rather than in this window. There is no
  // `WatchProjects`, so what makes this arrive is `Watch` on the tasks: the list is asked again
  // whenever the work under it changes.
  World.backend.theProjectsItHas = <Project>[
    for (final each in World.backend.theProjectsItHas)
      if (each.name == project)
        Project.from(<String, dynamic>{
          'name': each.name,
          'securityClass': each.securityClass,
          'file': each.file,
          'mirror': each.mirror,
          'prepared': each.prepared,
          'behind': each.behind,
          'behindMeasured': each.behindMeasured,
          'behindReason': each.behindReason,
          'pending': each.pending,
          'tasks': each.tasks + 1,
          'running': each.running + 1,
        })
      else
        each,
  ];
  World.backend.publish(<Task>[
    ...World.backend.tasksNow,
    Task.from(<String, dynamic>{
      'name': 'porelo-$project-elsewhere',
      'project': project,
      'securityClass': 'guarded',
      'state': 'Up 1 minute',
      'running': true,
      'helpers': 2,
    }),
  ]);
  await World.settle(tester);
}
