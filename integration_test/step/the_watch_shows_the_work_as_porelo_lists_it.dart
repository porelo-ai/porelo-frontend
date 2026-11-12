import 'package:flutter_test/flutter_test.dart';

import '../support/story_play.dart';

/// Usage: the watch shows the work as porelo lists it
Future<void> theWatchShowsTheWorkAsPoreloListsIt(WidgetTester tester) => played(
  tester,
  '11 the watch shows the work up, as porelo task list prints it',
  () async {
    await untilTheWatchShowsTheRow(tester, wanted: (row) => stateWord(row.state) == 'Up');
  },
  leansOn: 'watch',
  goesOn: true,
);
