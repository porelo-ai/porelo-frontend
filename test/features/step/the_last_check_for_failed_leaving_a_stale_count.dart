import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the last check for {'billing'} failed, leaving a stale count
Future<void> theLastCheckForFailedLeavingAStaleCount(WidgetTester tester, String project) async {
  // `behind` is meaningless unless the reason is MEASURED, and the contract says so. A daemon
  // that leaves the previous number in the field while reporting a failure is within its rights,
  // and drawing it would be this end inventing a measurement.
  World.backend.theProjectsItHas = <Project>[
    for (final each in World.backend.theProjectsItHas)
      if (each.name == project)
        Project.from(<String, dynamic>{
          'name': each.name,
          'securityClass': each.securityClass,
          'file': each.file,
          'mirror': each.mirror,
          'prepared': each.prepared,
          'behind': 7,
          'behindMeasured': each.behindMeasured,
          'behindReason': 'FAILED',
          'behindDetail': '',
          'pending': each.pending,
          'tasks': each.tasks,
          'running': each.running,
        })
      else
        each,
  ];
  await World.restartApp(tester);
}
