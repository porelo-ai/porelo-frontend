import 'package:flutter_test/flutter_test.dart';

import '../support/rehearsal.dart';

/// Usage: the gathered push to central is said not to run yet, with why
Future<void> theGatheredPushToCentralIsSaidNotToRunYetWithWhy(WidgetTester tester) async {
  // Driven once the host reads the person's central token from its vault, so that nothing is typed: until then the
  // host asks for it on its terminal, and the report says so rather than passing over it.
  notRunBecause('the gathered push to central waits on the host taking the central token from the vault');
}
