import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine is degraded at {'rootless network backend'} because {'slirp4netns'}
Future<void> theMachineIsDegradedAtBecause(WidgetTester tester, String what, String why) async {
  World.backend.theHealthItReports = Health(
    probes: <Probe>[
      const Probe(name: 'podman', state: 'OK', detail: '5.2.1', action: ''),
      Probe(name: what, state: 'DEGRADED', detail: why, action: 'install pasta (passt) and restart the daemon'),
    ],
    // Degraded leaves it ready: the machine runs tasks, and the report says how well.
    ready: true,
  );
}
