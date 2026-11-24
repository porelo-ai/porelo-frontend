import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the machine refuses the review summary as moved
Future<void> theMachineRefusesTheReviewSummaryAsMoved(WidgetTester tester) async {
  World.backend.refuseTheSummary = const VarlinkException('org.fuin.porelo.Tasks1.MovedSinceReview', <String, dynamic>{
    'name': 'migrate',
    'reviewed': '9a3c1f2e4b5d6a7c8e9f0a1b2c3d4e5f6a7b8c9d',
    'now': 'b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0',
  });
}
