import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine's own {'search'} takes the package's place at {'https://search.internal.example'}
Future<void> theMachinesOwnTakesThePackagesPlaceAt(WidgetTester tester, String name, String upstream) async {
  final here = World.backend.destinationsHere;
  for (var i = 0; i < here.length; i++) {
    final each = here[i];
    if (each.name == name && each.packaged) {
      here[i] = Destination(
          name: each.name, label: each.label, upstream: each.upstream, authHeader: each.authHeader,
          authPrefix: each.authPrefix, authQuery: each.authQuery, file: each.file, packaged: true, inForce: false);
    }
  }
  here.insert(
      0,
      Destination(
          name: name, label: name, upstream: upstream, authHeader: 'Authorization', authPrefix: 'Bearer ',
          authQuery: '', file: '/home/somebody/.local/share/porelo/destinations/$name.yaml',
          packaged: false, inForce: true));
}
