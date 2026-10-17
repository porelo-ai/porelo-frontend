import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: stopping following will refuse because {'HOLDS_WORK'}
Future<void> stoppingFollowingWillRefuseBecause(WidgetTester tester, String outcome) async {
  World.backend.deletionAnswers = DeleteOutcome(outcome);
}
