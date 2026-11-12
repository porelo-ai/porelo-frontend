import 'package:flutter_test/flutter_test.dart';

import '../support/idea_walk.dart';

/// Usage: the forge holds the work of the builder agent
Future<void> theForgeHoldsTheWorkOfTheBuilderAgent(WidgetTester tester) =>
    walked(tester, '7 read: the forge holds the work of the builder agent', () async {
      expect(hasEnded(await theTask(Walk.builder!)), isTrue, reason: 'porelo says ${Walk.builder} ended');
      noteStep(
        (await probe(['forge-moved', Walk.urlOf(Walk.issueRepository), Walk.issueHead]))
            .trimRight()
            .replaceAll(RegExp('^', multiLine: true), '   '),
      );
    });
