import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine is missing {'nft'} because {'no nftables binary on PATH'}
Future<void> theMachineIsMissingBecause(WidgetTester tester, String what, String why) async {
  World.backend.theHealthItReports = Health(
    probes: <Probe>[
      const Probe(name: 'podman', state: 'OK', detail: '5.2.1', action: ''),
      Probe(name: what, state: 'MISSING', detail: why, action: 'install nftables'),
    ],
    // False exactly when something is MISSING, and it is the daemon's own answer rather than one
    // this end re-derives.
    ready: false,
  );
}
