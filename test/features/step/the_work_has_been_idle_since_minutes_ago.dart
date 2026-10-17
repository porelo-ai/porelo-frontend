import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the work {'porelo-checkout-shell'} has been idle since {'40'} minutes ago
Future<void> theWorkHasBeenIdleSinceMinutesAgo(WidgetTester tester, String work, String minutes) async {
  final began = DateTime.now().toUtc().subtract(Duration(minutes: int.parse(minutes)));
  World.theWorkIs(work, activity: 'IDLE', since: began.toIso8601String());
  await World.settle(tester);
}
