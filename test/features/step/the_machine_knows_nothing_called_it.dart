import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine knows nothing called it
Future<void> theMachineKnowsNothingCalledIt(WidgetTester tester) async {
  World.backend.refuseToRemove = const VarlinkException('org.fuin.porelo.Tasks1.NoSuchProject', <String, dynamic>{
    'project': 'checkout',
  });
}
