import 'package:flutter_test/flutter_test.dart';

import '../support/developer_settings.dart';

Future<void> theRequestedDeveloperHasBothPublicLaptops(WidgetTester tester) async {
  final developer = developerSettings.additions.single;
  expect(developer.account, 'developer');
  expect(developer.forgeLogin, 'dev-login');
  expect(developer.laptops.map((l) => l.vpnAddress), ['10.77.0.3', '10.77.0.4']);
  expect(developer.laptops.map((l) => l.sshPublicKey), [developerSsh, developerSsh]);
  expect(developer.laptops.map((l) => l.wireguardPublicKey), [developerWg, developerWg]);
}
