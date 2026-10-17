import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: other work is blocked reaching {'files.example.test:22'} with {10} minutes left
Future<void> otherWorkIsBlockedReachingWithMinutesLeft(
    WidgetTester tester, String where, int minutes) async {
  final ends = DateTime.now().add(Duration(minutes: minutes, seconds: 30));
  World.backend.asking.add(World.blocked(where,
      task: 'porelo-billing-shell', deadline: ends.toUtc().toIso8601String()));
  await World.settle(tester);
}
