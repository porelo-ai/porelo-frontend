import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: work is blocked reaching {'api.example.test:443'} with {3} minutes left
Future<void> workIsBlockedReachingWithMinutesLeft(WidgetTester tester, String where, int minutes) async {
  // Half a minute over, so the whole minutes shown are exactly the ones asked for.
  final ends = DateTime.now().add(Duration(minutes: minutes, seconds: 30));
  World.backend.asking.add(World.blocked(where, deadline: ends.toUtc().toIso8601String()));
  await World.settle(tester);
}
