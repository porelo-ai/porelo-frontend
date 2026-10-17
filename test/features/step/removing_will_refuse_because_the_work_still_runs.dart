import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: removing will refuse because the work still runs
Future<void> removingWillRefuseBecauseTheWorkStillRuns(WidgetTester tester) async {
  World.backend.nextRemove = Removed.from(const <String, dynamic>{
    'outcome': 'STILL_RUNNING',
    'work': '',
    'rescuedRef': '',
    'removed': false,
    'discarded': 0,
  });
}
