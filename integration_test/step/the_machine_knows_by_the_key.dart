import 'package:flutter_test/flutter_test.dart';

import '../support/remote.dart';

/// Usage: the machine knows {'github.com'} by the key {'SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU'}
Future<void> theMachineKnowsByTheKey(WidgetTester tester, String host, String fingerprint) async {
  final listed = await onTheTestMachine('''
set -eu
ssh-keygen -l -F "$host" -f "\$HOME/.local/state/porelo/known_hosts" 2>/dev/null | grep -v '^#' || true
''');
  expect(listed, contains(fingerprint), reason: 'known_hosts has: $listed');
}
