import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine refuses the grant saying {'the service at auth.example.com could not be reached'}
Future<void> theMachineRefusesTheGrantSaying(WidgetTester tester, String words) async {
  World.backend.granting.addError(
    VarlinkException('org.fuin.porelo.Tasks1.Failed', <String, dynamic>{'message': words}),
  );
  await World.settle(tester);
}
