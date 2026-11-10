import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the central forge refuses the token
Future<void> theCentralForgeRefusesTheToken(WidgetTester tester) async {
  World.backend.centralRefuses = const VarlinkException('org.fuin.porelo.Tasks1.CentralTokenRefused', <String, dynamic>{
    'credential': 'acme.central',
    'storeCommand': <String>[],
    'repository': 'payments-api',
    'pushed': <String>[],
    'upToDate': <String>[],
    'forge': 'git.acme.example',
    'status': 401,
  });
}
