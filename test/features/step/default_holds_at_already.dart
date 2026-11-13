import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: default holds {'tools'} at {'git@example.org:acme/tools.git'} already
Future<void> defaultHoldsAtAlready(WidgetTester tester, String name, String upstream) async {
  World.backend.inDefault = <DefaultRepository>[
    ...World.backend.inDefault,
    DefaultRepository(name: name, upstream: upstream, checkout: '', claimedBy: ''),
  ];
  // Read again, as a machine answers what default holds in its list of projects too.
  await World.machines.fleet.refresh(quietly: true);
  await World.settle(tester);
}
