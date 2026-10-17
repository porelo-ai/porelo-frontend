import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the next follow is refused as {'NOT_SIGNED'}
Future<void> theNextFollowIsRefusedAs(WidgetTester tester, String outcome) async {
  World.backend.nextFollow = Followed(
    name: 'payments',
    outcome: outcome,
    refused: 'badc0de4f5a6',
    needsAPerson: true,
  );
}
