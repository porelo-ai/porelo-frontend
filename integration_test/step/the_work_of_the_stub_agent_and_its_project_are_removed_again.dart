import 'package:flutter_test/flutter_test.dart';

import '../support/remote.dart';
import '../support/story_play.dart';

/// Usage: the work of the stub agent and its project are removed again
Future<void> theWorkOfTheStubAgentAndItsProjectAreRemovedAgain(WidgetTester tester) =>
    played(tester, '18 the work of the stub agent and its project are removed again', () async {
      Played.reach?.kill();
      await Played.beside?.close();
      Played.beside = null;
      final container = Played.container ?? containerOf(Played.project, Played.task);
      final left = await onTheTestMachine('''
PATH="\$HOME/.local/bin:\$PATH"
${removingTheWork(container, Played.project)}
porelo task list
porelo project list
''');
      expect(
        left,
        isNot(contains(RegExp('\\b${RegExp.escape(Played.project)}\\b'))),
        reason: '${Played.project} is still listed',
      );
    });
