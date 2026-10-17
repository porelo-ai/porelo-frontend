import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the branch {'fix-rounding'} already holds earlier work
///
/// The branch at the upstream holds a commit the reviewed work did not grow from: the machine
/// refuses the forward, typed, before anything is pushed.
Future<void> theBranchAlreadyHoldsEarlierWork(WidgetTester tester, String branch) async {
  World.backend.refuseTheGate = VarlinkException('org.fuin.porelo.Tasks1.BranchExists', <String, dynamic>{
    'branch': branch,
    'at': '4d2e9a1c03b7',
  });
}
