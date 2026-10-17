import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: a refresh moves {'main'} to {'111df4193e7e0011'}
Future<void> aRefreshMovesTo(WidgetTester tester, String branch, String commit) async {
  World.backend.taskRefreshAnswers = TaskRefreshed(outcome: 'MOVED', moved: <String, String>{branch: commit}, told: true);
}
