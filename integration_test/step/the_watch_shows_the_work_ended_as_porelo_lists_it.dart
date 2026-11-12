import 'package:flutter_test/flutter_test.dart';

import '../support/story_play.dart';

/// Usage: the watch shows the work ended as porelo lists it
Future<void> theWatchShowsTheWorkEndedAsPoreloListsIt(WidgetTester tester) => played(
  tester,
  '15 the watch shows the work ended, as porelo task list prints it',
  () async {
    await untilTheWatchShowsTheRow(tester);
  },
  leansOn: 'watch',
  goesOn: true,
);
