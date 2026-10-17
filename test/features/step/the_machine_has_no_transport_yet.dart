import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the machine has no transport yet
Future<void> theMachineHasNoTransportYet(WidgetTester tester) async {
  World.setup.lists = '{"packages": ['
      '{"name": "porelo-agent-claude", "kind": "agent", "description": "Claude Code", '
      '"installed": false, "version": "1.0.0"}, '
      '{"name": "porelo-message-transport-matrix", "kind": "transport", '
      '"description": "Matrix transport", "installed": false, "version": "1.0.0"}, '
      '{"name": "porelo-matrix-homeserver", "kind": "homeserver", '
      '"description": "A Matrix homeserver on this machine", "installed": false, "version": "1.0.0"}]}';
}
