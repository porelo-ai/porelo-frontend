import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';

/// Usage: I try the test machine from the dialog with the socket {'/run/user/0/porelo/none.sock'}
Future<void> iTryTheTestMachineFromTheDialogWithTheSocket(WidgetTester tester, String socket) =>
    tryFromTheDialog(tester, socket);
