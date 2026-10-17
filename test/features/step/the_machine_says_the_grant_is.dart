import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine says the grant is {'granted'}
Future<void> theMachineSaysTheGrantIs(WidgetTester tester, String state) async {
  World.backend.granting
      .add(AuthorizeProgress(state: state, detail: state == 'failed' ? 'the service answered invalid_client' : ''));
  await World.backend.granting.close();
  // Granted, the machine no longer answers that it needs one.
  if (state == 'granted') World.backend.grantNeededFor = null;
  await World.settle(tester);
}
