import 'package:flutter_test/flutter_test.dart';

import '../support/idea_walk.dart';

/// Usage: the forge holds the work of the builder agent
Future<void> theForgeHoldsTheWorkOfTheBuilderAgent(WidgetTester tester) =>
    walked(tester, '7 read: the forge holds the work of the builder agent', () async {
      for (final builder in Walk.builders) {
        expect(hasEnded(await theTask(builder)), isTrue, reason: 'porelo says $builder ended');
      }
      for (final repository in Walk.issueRepositories) {
        noteStep(
          (await probe(['forge-moved', Walk.urlOf(repository), Walk.issueHeadOf(repository)]))
              .trimRight()
              .replaceAll(RegExp('^', multiLine: true), '   '),
        );
      }
    });
