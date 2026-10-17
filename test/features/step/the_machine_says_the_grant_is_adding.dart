import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine says the grant is {'granted'}, adding {'the service gave a token that does not expire'}
Future<void> theMachineSaysTheGrantIsAdding(WidgetTester tester, String state, String detail) async {
  World.backend.granting.add(AuthorizeProgress(state: state, detail: detail));
  await World.backend.granting.close();
  if (state == 'granted') World.backend.grantNeededFor = null;
  await World.settle(tester);
}
