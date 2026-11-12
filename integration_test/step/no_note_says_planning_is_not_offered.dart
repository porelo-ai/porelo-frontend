import 'package:flutter_test/flutter_test.dart';

import '../support/story_play.dart';
import 'i_open_planning.dart';

/// Usage: no note says planning is not offered
Future<void> noNoteSaysPlanningIsNotOffered(WidgetTester tester) => played(
  tester,
  '4 no note says planning is not offered',
  () async {
    final said = [
      for (final each in planningNotOffered)
        if (find.text(each).evaluate().isNotEmpty) each,
    ];
    if (said.isNotEmpty) fail('asked for no note that planning is not offered; the window says: ${said.join(' / ')}');
  },
  leansOn: 'window-planner',
  goesOn: true,
);
