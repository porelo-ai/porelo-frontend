import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine declares the destination {'weather'} at {'https://api.weather.example/v1'}
Future<void> theMachineDeclaresTheDestinationAt(WidgetTester tester, String name, String upstream) async {
  World.backend.destinationsHere.add(
    Destination(
      name: name,
      label: name,
      upstream: upstream,
      authHeader: 'Authorization',
      authPrefix: 'Bearer ',
      authQuery: '',
      file: '/home/somebody/.local/share/porelo/destinations/$name.yaml',
      packaged: false,
      inForce: true,
    ),
  );
}
