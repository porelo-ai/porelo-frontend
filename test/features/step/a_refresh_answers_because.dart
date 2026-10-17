import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: a refresh answers {'FAILED'} because {'the checkout /home/somebody/work/app is gone'}
Future<void> aRefreshAnswersBecause(WidgetTester tester, String outcome, String detail) async {
  World.backend.taskRefreshAnswers = TaskRefreshed(outcome: outcome, detail: detail);
}
