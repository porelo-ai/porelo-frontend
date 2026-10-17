import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: removing will refuse because the work is held
Future<void> removingWillRefuseBecauseTheWorkIsHeld(WidgetTester tester) async {
  // On demand, without contriving a task that genuinely holds commits — which is the whole
  // reason a refusal can be tested at all.
  World.backend.nextRemove = Removed.from(const <String, dynamic>{
    'outcome': 'HOLDS_WORK',
    'work': '2 commits on refs/heads/fix-rounding',
    'rescuedRef': '',
    'removed': false,
    'discarded': 0,
  });
}
