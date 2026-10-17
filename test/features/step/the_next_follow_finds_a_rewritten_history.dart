import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the next follow finds a rewritten history
Future<void> theNextFollowFindsARewrittenHistory(WidgetTester tester) async {
  World.backend.nextFollow = const Followed(
    name: 'payments',
    outcome: 'REWRITTEN',
    refused: 'badc0de4f5a6',
    detail: 'badc0de is signed and does not descend from 4f2a9c1',
    needsAPerson: true,
  );
}
