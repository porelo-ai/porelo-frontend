import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: a refresh answers {'NOT_GATED'}
Future<void> aRefreshAnswers(WidgetTester tester, String outcome) async {
  World.backend.taskRefreshAnswers = TaskRefreshed(outcome: outcome);
}
