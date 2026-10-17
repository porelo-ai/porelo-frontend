import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: default holds {'api'} at {'git@github.com:acme/api.git'}, named by {'payments'} too
Future<void> defaultHoldsAtNamedByToo(WidgetTester tester, String name, String upstream, String project) async {
  World.backend.inDefault = <DefaultRepository>[
    DefaultRepository(name: name, upstream: upstream, checkout: '', claimedBy: project),
  ];
}
