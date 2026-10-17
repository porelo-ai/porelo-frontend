import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the login prints its page {'https://claude.com/cai/oauth/authorize'} and its reply port {'42017'}
Future<void> theLoginPrintsItsPageAndItsReplyPort(WidgetTester tester, String address, String port) async {
  // Exactly as Porelo's BROWSER helper writes it (37dcf74): a marked OSC 8 and OSC 5379, closed with BEL.
  World.terminals.last.prints(
    '=== Open this in a browser on your own machine: ===\r\n'
    '\x1b]8;id=porelo-login;$address\x07$address\x1b]8;;\x07\r\n'
    '\x1b]5379;forward;$port\x07'
    '    it will answer on localhost:$port of the machine\r\n',
  );
  await World.settle(tester);
}
