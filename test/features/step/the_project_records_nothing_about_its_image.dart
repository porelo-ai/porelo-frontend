import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the project {'checkout'} records nothing about its image
///
/// An image built by an older Porelo, or one whose project file has moved. **Not stale**: nothing
/// knows either way, and rebuilding for no reason is how the word stops being read.
Future<void> theProjectRecordsNothingAboutItsImage(WidgetTester tester, String name) async {
  World.backend.theProjectsItHas = <Project>[
    for (final project in World.backend.theProjectsItHas)
      if (project.name != name)
        project
      else
        Project.from(<String, dynamic>{
          'name': project.name,
          'securityClass': project.securityClass,
          'file': project.file,
          'mirror': project.mirror,
          'prepared': true,
          'preparedState': 'UNKNOWN',
          'behindReason': project.behindReason,
          'pending': project.pending,
          'tasks': project.tasks,
          'running': project.running,
        }),
  ];
}
