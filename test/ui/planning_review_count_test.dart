import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_planning/porelo_planning.dart' show PlanningFilter, PlanningView;

import '../features/support/world.dart';

/// A project's board whose open-work figures say [review] issues wait for the person's review.
Map<String, dynamic> _board({required int review}) => {
  'states': [
    {'name': 'Ready', 'kind': 'WAITING'},
    {'name': 'Review', 'kind': 'WAITING'},
  ],
  'phases': [
    {
      'name': 'Work',
      'states': ['Ready', 'Review'],
    },
  ],
  'stories': [
    {'id': 'StoryOne', 'title': 'A story with work in review', 'state': 'Ready', 'issues': <Map<String, dynamic>>[]},
  ],
  'open': {
    'states': [
      {'name': 'Review', 'issues': review},
    ],
    'blocked': 0,
    'sizes': <Object>[],
    'unsized': 0,
    'left': review,
    'unestimated': review,
    'review': review,
  },
  'revision': 'initial',
};

void main() {
  final count = find.byKey(const Key('rail-review-count'));

  // Harm: the issues waiting for the person's review are seen only on the board, or a project the planner serves is
  // left out of the count beside Needs you.
  testWidgets("the planner's issues in review are counted beside Needs you over every project", (tester) async {
    await World.startBackend(World.work);
    World.backend.theProjectsItHas = [
      Project.from({'name': 'checkout'}),
      Project.from({'name': 'billing'}),
    ];
    World.planning.boards['checkout'] = _board(review: 2);
    World.planning.boards['billing'] = _board(review: 3);
    await World.startApp(tester);
    await World.settle(tester);

    expect(find.descendant(of: count, matching: find.text('5')), findsOneWidget);

    await tester.tap(count);
    await World.settle(tester);
    expect(World.shell.section, Section.planning);
    expect(World.shell.place.planningFilter, PlanningFilter.review);
  });

  // Harm: the count says issues wait, and pressing it shows a board where none waits.
  testWidgets('pressing the review count opens a project that has issues in review', (tester) async {
    await World.startBackend(World.work);
    World.backend.theProjectsItHas = [
      Project.from({'name': 'checkout'}),
      Project.from({'name': 'billing'}),
    ];
    World.planning.boards['checkout'] = _board(review: 0);
    World.planning.boards['billing'] = _board(review: 3);
    await World.startApp(tester);
    await World.settle(tester);

    expect(find.descendant(of: count, matching: find.text('3')), findsOneWidget);
    await tester.tap(count);
    await World.settle(tester);
    expect(World.shell.place.project, 'billing');
    expect(World.shell.place.planningFilter, PlanningFilter.review);
  });

  // Harm: the title bar says Planning whichever view is open, so it does not tell Board from Open work.
  testWidgets('the title bar names the view opened under Planning', (tester) async {
    await World.startBackend(World.work);
    World.backend.theProjectsItHas = [
      Project.from({'name': 'checkout'}),
    ];
    World.planning.boards['checkout'] = _board(review: 1);
    await World.startApp(tester);
    World.shell.choosePlace(const ShellPlace(Section.planning));
    await World.settle(tester);
    final title = find.descendant(of: find.byType(AppBar), matching: find.text('Board'));
    expect(title, findsOneWidget);

    World.shell.choosePlace(const ShellPlace(Section.planning, planningView: PlanningView.openWork));
    await World.settle(tester);
    expect(find.descendant(of: find.byType(AppBar), matching: find.text('Open work')), findsOneWidget);
  });
}
