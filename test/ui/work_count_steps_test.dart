import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/page_explanation.dart';

import '../features/step/nothing_needs_me.dart';
import '../features/step/the_count_of_what_needs_a_person_is.dart';
import '../features/step/the_list_of_work_counts.dart';

void main() {
  // Harm: a green feature step conceals a wrong or missing displayed Work count.
  for (final subtitle in <String?>['99 pieces of work', null]) {
    testWidgets('the Work count step rejects subtitle $subtitle despite four rows', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                PageHead(title: 'Work', subtitle: subtitle, subtitleKey: const Key('work-list-subtitle')),
                for (var row = 0; row < 4; row++) SizedBox(key: ValueKey<String>('tile here work-$row')),
              ],
            ),
          ),
        ),
      );
      await expectLater(theListOfWorkCounts(tester, 4), throwsA(isA<TestFailure>()));
    });
  }

  // Harm: a hidden badge makes a false or missing empty-state subtitle pass the feature step.
  for (final subtitle in <String?>['1 need you', null]) {
    testWidgets('the empty Needs you step rejects subtitle $subtitle despite a hidden badge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Badge(key: Key('needing-count-badge'), isLabelVisible: false, label: Text('0')),
                if (subtitle != null) Text(subtitle, key: const Key('needs-you-subtitle')),
              ],
            ),
          ),
        ),
      );
      await expectLater(nothingNeedsMe(tester), throwsA(isA<TestFailure>()));
    });
  }

  // Harm: the count step reports success from the badge while Needs you omits or contradicts its total.
  for (final subtitle in <String?>['99 need you', null]) {
    testWidgets('the Needs you count step rejects subtitle $subtitle despite a matching badge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Badge(key: Key('needing-count-badge'), label: Text('1')),
                if (subtitle != null) Text(subtitle, key: const Key('needs-you-subtitle')),
              ],
            ),
          ),
        ),
      );
      await expectLater(theCountOfWhatNeedsAPersonIs(tester, '1 need you'), throwsA(isA<TestFailure>()));
    });
  }
}
