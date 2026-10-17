import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: root logged in to {'203.0.113.10'} with {'porelo-the-build-machine'}
Future<void> rootLoggedInToWith(WidgetTester tester, String host, String key) async {
  expect(World.setup.rootLogins, hasLength(1));
  expect(World.setup.rootLogins.single.host, host);
  expect(World.setup.rootLogins.single.key, '${World.setup.home.path}/.ssh/$key');
}
