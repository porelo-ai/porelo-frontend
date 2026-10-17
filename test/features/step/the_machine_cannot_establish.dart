import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine cannot establish {'SELinux policy'}
Future<void> theMachineCannotEstablish(WidgetTester tester, String what) async {
  World.backend.theHealthItReports = Health(
    probes: <Probe>[
      const Probe(name: 'podman', state: 'OK', detail: '5.2.1', action: ''),
      Probe(name: what, state: 'UNKNOWN', detail: 'nothing here could tell', action: 'check it on the machine'),
    ],
    ready: true,
  );
}
