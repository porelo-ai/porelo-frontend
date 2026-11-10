import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/planning_embedding.dart';
import 'package:porelo_planning/porelo_planning.dart';

import '../features/support/world.dart';

void main() {
  // Harm: a window that reaches no planner shows an empty board, or a board of its own, as if it planned.
  testWidgets('a window without planning says where planning comes from and shows no board', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester, planningServed: false);

    World.shell.goTo(Section.planning);
    await World.settle(tester);

    expect(find.text(planningNotReached), findsOneWidget);
    expect(find.byType(PlanningScreen), findsNothing);
    expect(find.byKey(const ValueKey('rail planning')), findsOneWidget, reason: 'the rail keeps the place');
    expect(find.byKey(const Key('rail-planning-count')), findsNothing, reason: 'nothing is counted without a planner');
  });

  // Harm: the planning a window was given is hidden behind the line for a window without one.
  testWidgets('a window given planning shows its board and not the line', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);

    World.shell.goTo(Section.planning);
    await World.settle(tester);

    expect(find.byType(PlanningScreen), findsOneWidget);
    expect(find.text(planningNotReached), findsNothing);
  });
}
