import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine refuses the name {'www.iana.org'} on purpose
Future<void> theMachineRefusesTheNameOnPurpose(WidgetTester tester, String name) async {
  // What a Porelo answers for a name an agent, a project or a repository refuses: the
  // resolver would not honour it, so nothing is widened.
  World.backend.nextWidening = Widened.from(<String, dynamic>{
    'outcome': 'REFUSED_NAME',
    'opens': <String>[],
    'persisted': false,
    'detail': '$name is refused by the project',
  });
}
