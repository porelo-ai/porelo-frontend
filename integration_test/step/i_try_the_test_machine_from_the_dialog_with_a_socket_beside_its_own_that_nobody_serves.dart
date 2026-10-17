import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';

/// Usage: I try the test machine from the dialog with a socket beside its own that nobody serves
///
/// In the login's own runtime directory, so the only thing missing is a daemon at that path — the
/// case a socket in another user's directory must not be mistaken for, and never the other way.
Future<void> iTryTheTestMachineFromTheDialogWithASocketBesideItsOwnThatNobodyServes(WidgetTester tester) {
  final own = E2e.remoteSocket;
  return tryFromTheDialog(tester, '${own.substring(0, own.lastIndexOf('/'))}/none.sock');
}
