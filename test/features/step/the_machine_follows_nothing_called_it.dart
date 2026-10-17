import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine follows nothing called it
Future<void> theMachineFollowsNothingCalledIt(WidgetTester tester) async {
  // What Porelo answered on the VM for a project left from before following.
  World.backend.refuseToUnfollow = const VarlinkException(
      'org.fuin.porelo.Tasks1.NoSuchProject', <String, dynamic>{'project': 'checkout'});
}
