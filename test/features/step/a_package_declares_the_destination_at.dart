import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: a package declares the destination {'search'} at {'https://api.search.example'}
Future<void> aPackageDeclaresTheDestinationAt(WidgetTester tester, String name, String upstream) async {
  World.backend.destinationsHere.add(
    Destination(
      name: name,
      label: name,
      upstream: upstream,
      authHeader: 'X-Api-Key',
      authPrefix: '',
      authQuery: '',
      file: '/usr/share/porelo/destinations/$name.yaml',
      packaged: true,
      inForce: true,
    ),
  );
}
