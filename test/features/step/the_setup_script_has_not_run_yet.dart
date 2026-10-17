import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the setup script has not run yet
Future<void> theSetupScriptHasNotRunYet(WidgetTester tester) async {
  // Asking what it could install and for --show is all root has done.
  expect(World.setup.asRootRan.where((script) => script.contains('\nbash /root/porelo-setup.sh')),
      isEmpty);
}
