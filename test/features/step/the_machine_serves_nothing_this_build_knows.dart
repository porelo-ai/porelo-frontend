import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine serves nothing this build knows
Future<void> theMachineServesNothingThisBuildKnows(WidgetTester tester) async {
  World.backend.whatItIs = const ServiceInfo(
    product: 'Porelo',
    version: '9.0.0',
    vendor: 'fuin.org',
    interfaces: <String>['org.varlink.service', 'org.fuin.porelo.Tasks2'],
  );
}
