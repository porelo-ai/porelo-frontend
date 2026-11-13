import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: default holds {'tools'} from the remote {'git@example.org:acme/tools.git'}
Future<void> defaultHoldsFromTheRemote(WidgetTester tester, String name, String remote) async {
  World.backend.inDefault = <DefaultRepository>[
    ...World.backend.inDefault,
    DefaultRepository(name: name, upstream: remote, checkout: '', claimedBy: '', source: 'REMOTE', remote: remote),
  ];
  // Read again, as a machine answers what default holds in its list of projects too.
  await World.machines.fleet.refresh(quietly: true);
  await World.settle(tester);
}
