import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: Porelo answers a release that it cannot be sent, saying {detail}
Future<void> poreloAnswersAReleaseThatItCannotBeSentSaying(WidgetTester tester, String detail) async {
  World.backend.notDeliverable = detail;
}
