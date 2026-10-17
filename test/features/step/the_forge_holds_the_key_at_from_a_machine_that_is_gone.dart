import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the forge holds the key {'porelo old-box api/api'} at {'acme/api'} from a machine that is gone
Future<void> theForgeHoldsTheKeyAtFromAMachineThatIsGone(WidgetTester tester, String title, String repository) async {
  await World.forge.addDeployKey(repository, title: title, key: 'ssh-ed25519 AAAAold porelo@old-box', readOnly: true);
}
