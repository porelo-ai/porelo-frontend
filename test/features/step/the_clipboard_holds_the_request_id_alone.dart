import 'package:flutter_test/flutter_test.dart';

import '../support/held_saves.dart';
import '../support/world.dart';

/// Usage: the clipboard holds the request id alone
Future<void> theClipboardHoldsTheRequestIdAlone(WidgetTester tester) async {
  expect(World.copied, [heldRequestId]);
}
