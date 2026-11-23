import 'package:flutter_test/flutter_test.dart';

import '../support/idea_walk.dart';

/// Usage: the forge holds the work of the builder agent
Future<void> theForgeHoldsTheWorkOfTheBuilderAgent(WidgetTester tester) =>
    walked(tester, '7 read: the forge holds the work of the builder agent', () async {
      for (final builder in Walk.builders) {
        expect(hasEnded(await theTask(builder)), isTrue, reason: 'porelo says $builder ended');
      }
      // The very commit each builder landed, as porelo records it, held by the forge on whichever ref the gate passed
      // it on as: an online task's work reaches the forge as a branch of its own, never the default branch.
      await theForgeHoldsTheLandedCommits();
    });
