import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the repository {'payments-api'} adds {'api.stripe.com'}
Future<void> theRepositoryAdds(WidgetTester tester, String repository, String host) async {
  World.backend.theRepositoryAdds[repository] = <EgressHost>[
    EgressHost(host: host, origin: 'repository $repository'),
  ];
}
