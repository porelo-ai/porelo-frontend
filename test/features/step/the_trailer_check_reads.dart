import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/makers.dart';

/// Usage: the trailer check reads {'wrong'}
Future<void> theTrailerCheckReads(WidgetTester tester, String state) async {
  for (final each in TrailerState.values) {
    expect(
      find.byKey(ValueKey<String>('review-trailer-check ${each.name}')),
      each.name == state ? findsOneWidget : findsNothing,
      reason: 'the trailer check reads ${each.name}',
    );
  }
}
