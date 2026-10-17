import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';

/// Usage: I try the test machine from the dialog
Future<void> iTryTheTestMachineFromTheDialog(WidgetTester tester) => tryFromTheDialog(tester, E2e.remoteSocket);
