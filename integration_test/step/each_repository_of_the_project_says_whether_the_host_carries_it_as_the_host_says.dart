import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/rehearsal.dart';

/// Usage: each repository of the project says whether the host carries it, as the host says
Future<void> eachRepositoryOfTheProjectSaysWhetherTheHostCarriesItAsTheHostSays(WidgetTester tester) async {
  final project = await theProjectOnTheHost();
  expect(project, isNotNull, reason: 'the host lists ${Rehearsal.project}');
  final repositories = (project!['repositories'] as List<dynamic>? ?? const []).whereType<Map<String, dynamic>>();
  expect(repositories, isNotEmpty, reason: 'the host names its repositories');
  for (final each in repositories) {
    final name = each['name'] as String;
    final row = find.byKey(Key('repository-$name'));
    await pumpUntil(tester, () => row.evaluate().isNotEmpty, what: 'a row for $name');
    final said = tester
        .widgetList<Text>(find.descendant(of: row, matching: find.byType(Text)))
        .map((t) => t.data ?? '')
        .join(' · ');
    switch (each['carriedHere']) {
      case true:
        // "carried: not read" holds the word too, and says the window did not read it.
        expect(said, matches(RegExp(r'(^|· )carried( ·|$)')), reason: name);
      case false:
        expect(said, contains('not carried'), reason: name);
      default:
        // The host did not say: the row must not say carried on its own word.
        expect(said, isNot(matches(RegExp(r'(^|· )carried( ·|$)'))), reason: name);
    }
  }
}
