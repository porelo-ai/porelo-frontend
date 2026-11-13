import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: default holds {'app'} from the checkout {'/home/somebody/work/app'} whose remote is {'git@example.org:app.git'}
Future<void> defaultHoldsFromTheCheckoutWhoseRemoteIs(
  WidgetTester tester,
  String name,
  String checkout,
  String remote,
) async {
  World.backend.inDefault = <DefaultRepository>[
    ...World.backend.inDefault,
    DefaultRepository(
      name: name,
      upstream: checkout,
      checkout: checkout,
      claimedBy: '',
      source: 'CHECKOUT',
      remote: remote,
    ),
  ];
  // Read again, as a machine answers what default holds in its list of projects too.
  await World.machines.fleet.refresh(quietly: true);
  await World.settle(tester);
}
