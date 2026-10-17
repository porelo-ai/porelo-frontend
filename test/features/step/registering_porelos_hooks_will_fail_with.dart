import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: registering Porelo's hooks will fail with {'podman: cannot write hooks.d'}
Future<void> registeringPorelosHooksWillFailWith(WidgetTester tester, String said) async {
  World.setup.registeringFails = said;
}
