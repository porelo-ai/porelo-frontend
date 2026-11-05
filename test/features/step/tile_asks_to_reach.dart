import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: {1} tile asks to reach {'api.example.test'}
Future<void> tileAsksToReach(WidgetTester tester, int count, String host) async {
  expect(
    find.ancestor(of: find.textContaining('asks to reach $host'), matching: find.byType(Card)),
    findsNWidgets(count),
  );
}
