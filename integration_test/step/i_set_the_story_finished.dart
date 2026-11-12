import 'package:flutter_test/flutter_test.dart';

import '../support/idea_walk.dart';

/// Usage: I set the story Finished
Future<void> iSetTheStoryFinished(WidgetTester tester) =>
    walked(tester, '10 the person sets the story Finished', () async {
      await toTheStory(tester);
      for (final issue in Walk.issues) {
        await moveAndSave(tester, issue.id, 'Finished');
      }
    });
