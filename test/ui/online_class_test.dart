import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/machine_tree.dart';

import '../features/step/i_select_the_project.dart';
import '../features/support/tiles.dart';
import '../features/support/world.dart';
import '../support/expand_list_rows.dart';

const _name = 'porelo-checkout-shell';

/// The usual work, [_name] in a project of [securityClass] saying its work waits, unattended, its agent finished with
/// nothing outside the gate: nothing of its end needs a person, so only its gate could.
List<Task> _finishedIn(String securityClass) => <Task>[
  for (final task in World.work)
    if (task.name != _name)
      task
    else
      Task.from(<String, dynamic>{
        ...wire(task),
        'securityClass': securityClass,
        'waiting': 1,
        'mode': 'UNATTENDED',
        'activity': 'ENDED',
        'agentEnded': <String, dynamic>{
          'at': '2026-11-10T09:00:00Z',
          'finished': true,
          'error': '',
          'source': '',
          'unpushed': 0,
        },
      }),
];

/// The usual work, [_name] in an `online` project saying its work waits and its agent stopped before its end.
List<Task> _online() => <Task>[
  for (final task in World.work)
    if (task.name != _name)
      task
    else
      Task.from(<String, dynamic>{
        ...wire(task),
        'securityClass': 'online',
        'waiting': 1,
        'activity': 'ENDED',
        'agentEnded': <String, dynamic>{
          'at': '2026-11-10T09:00:00Z',
          'finished': false,
          'error': 'it stopped',
          'source': '',
          'unpushed': 0,
        },
      }),
];

/// [project] as the machine lists it, in class [securityClass] with [pending] pushes its `Pending` lists.
Project _projectIn(Project project, String securityClass, int pending) => Project.from(<String, dynamic>{
  'name': project.name,
  'securityClass': securityClass,
  'file': project.file,
  'mirror': project.mirror,
  'prepared': true,
  'preparedState': 'READY',
  'pending': pending,
  'tasks': project.tasks,
  'running': project.running,
});

Finder _textIn(Finder where, String words) => find.descendant(of: where, matching: find.textContaining(words));

void main() {
  // Harm: an online task's push goes to the forge unreviewed, yet the window says it waits for review, counts it as
  // needing a person and offers a review nobody can give.
  testWidgets('an online task derives no gate on any screen', (tester) async {
    await World.startBackend(_online());
    await World.startApp(tester);
    final here = World.machines.current.name;

    World.shell.goTo(Section.attention);
    await World.settle(tester);
    final open = find.byKey(const Key('open-attention'));
    await expandListRows(tester, within: open);
    await World.settle(tester);
    Finder rowsOf(String prefix) => find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> && key.value.startsWith('attention-row $prefix');
    });
    expect(rowsOf('ended $here/$_name'), findsOneWidget, reason: 'its end still needs a person');
    expect(rowsOf('gate $here/$_name'), findsNothing);
    final itsRows = rowsOf('ended $here/$_name');
    for (final words in ['at the gate', 'waits for review']) {
      expect(_textIn(itsRows, words), findsNothing, reason: words);
    }

    World.shell.goTo(Section.work);
    await World.settle(tester);
    await tester.tap(tileFor(_name));
    await World.settle(tester);
    final gate = find.descendant(of: tileFor(_name), matching: find.byKey(const ValueKey<String>('tile-fact gate')));
    expect(tester.widget<Text>(gate).data, 'nothing is reviewed in an online project');
    for (final words in ['waits at the gate', 'waits for review']) {
      expect(_textIn(tileFor(_name), words), findsNothing, reason: words);
    }
  });

  // Harm: a push the gate still holds is hidden because its project is online, and nobody decides it.
  testWidgets("an online project's push its gate still lists is shown, and a guarded one keeps its words", (
    tester,
  ) async {
    await World.startBackend(World.work);
    World.backend.theProjectsItHas = <Project>[
      for (final project in World.backend.theProjectsItHas)
        if (project.name == 'checkout')
          _projectIn(project, 'online', 2)
        else if (project.name == 'unrecorded')
          _projectIn(project, 'guarded', 1)
        else
          project,
    ];
    await World.startApp(tester);
    await lookingAtTheProjects(tester, () async {
      expect(whatTheRowOfSays(tester, 'checkout'), contains('2 waiting for review'));
      expect(whatTheRowOfSays(tester, 'unrecorded'), contains('1 waiting for review'));
    });
    await iSelectTheProject(tester, 'checkout');
    expect(find.byType(ProjectHeader), findsOneWidget);
    expect(
      find.descendant(of: find.byType(ProjectHeader), matching: find.textContaining('2 waiting at the gate')),
      findsOneWidget,
    );
  });
  // Harm: with nothing else of it needing a person, an online task's work is said to wait for review on its row and
  // counted as needing somebody, though nothing is ever reviewed there.
  testWidgets('an online task whose end needs nobody is said and counted as needing nobody', (tester) async {
    await World.startBackend(_finishedIn('online'));
    await World.startApp(tester);
    World.shell.goTo(Section.work);
    await World.settle(tester);
    await tester.tap(tileFor(_name));
    await World.settle(tester);
    for (final words in ['waits for review', 'waits at the gate', 'Needs you']) {
      expect(_textIn(tileFor(_name), words), findsNothing, reason: words);
    }
    final ended = find.descendant(of: tileFor(_name), matching: find.byKey(const Key('tile-run-ended')));
    expect(
      tester.widget<Text>(ended).data,
      'Finished, in an online project, where nothing is reviewed: its output above says what it did.',
    );

    String badge() => tester
        .widget<Text>(find.descendant(of: find.byKey(const Key('needing-count-badge')), matching: find.byType(Text)))
        .data!;
    final online = badge();
    World.backend.publish(_finishedIn('guarded'));
    await World.settle(tester);
    expect(int.parse(badge()), int.parse(online) + 1, reason: 'the same work, guarded, waits for review');
    expect(_textIn(tileFor(_name), 'waits for review'), findsWidgets);
  });
}
