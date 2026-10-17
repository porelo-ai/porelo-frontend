import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine has the project default
Future<void> theMachineHasTheProjectDefault(WidgetTester tester) async {
  World.backend.theProjectsItHas = <Project>[
    ...World.backend.theProjectsItHas,
    // As Porelo lists it: a file of Porelo's own, where nobody writes, and followed by nobody.
    Project.from(const <String, dynamic>{
      'name': defaultProject,
      'securityClass': 'guarded',
      'file': '/home/me/.local/state/porelo/default/project.yml',
      'following': null,
    }),
  ];
}
