import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: removing will refuse because {60} commits are held
Future<void> removingWillRefuseBecauseCommitsAreHeld(WidgetTester tester, int commits) async {
  World.backend.nextRemove = Removed.from(<String, dynamic>{
    'outcome': 'HOLDS_WORK',
    'work': <String>[for (var each = 0; each < commits; each++) 'commit $each on refs/heads/long-run'].join('\n'),
    'rescuedRef': '',
    'removed': false,
    'discarded': 0,
  });
}
