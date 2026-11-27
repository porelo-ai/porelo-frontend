import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../features/support/tiles.dart';
import '../features/support/world.dart';

/// What a run's row says of its place, and of whose work it is, read from the machine's task record.
void main() {
  Task task(String name, {Object? workspace, Object? place}) => Task.from(<String, dynamic>{
    'name': 'porelo-walk_$name',
    'task': name,
    'project': 'walk',
    'running': true,
    'mode': 'UNATTENDED',
    'workspace': ?workspace,
    'place': ?place,
  });

  Future<void> onTheWork(WidgetTester tester, List<Task> tasks) async {
    await World.startBackend(tasks);
    await World.startApp(tester);
    await toThePlace(tester, 'work');
    await World.settle(tester);
  }

  Finder run(String words) => find.descendant(
    of: workRows(),
    matching: find.byWidgetPredicate(
      (widget) => widget is Text && widget.key == const Key('tile-run') && widget.data == words,
    ),
  );

  // Harm: a person cannot tell which run reads which pull request, and decides or stops the wrong one.
  testWidgets("a task reading another task's work and one on its own each say their place on the row", (tester) async {
    await onTheWork(tester, [
      task('reviewer', workspace: 'foreign', place: {'pullRequest': 'https://github.com/owner/repo/pull/17'}),
      task(
        'author',
        workspace: 'own',
        place: {
          'gatePush': {'name': 'author'},
        },
      ),
    ]);
    expect(run("reading another task's work at pull request owner/repo#17"), findsOneWidget);
    expect(run('at the gate push author'), findsOneWidget);
  });

  // Harm: a place made up where the machine said none is believed.
  testWidgets('a task the machine names no place for says none', (tester) async {
    await onTheWork(tester, [task('plain')]);
    expect(find.byKey(const Key('tile-run')), findsNothing);
  });

  group('the place as the machine says it', () {
    // Harm: a place in a shape not understood is shown as some other place.
    test('a place with none or several parts set is not read', () {
      expect(RunPlace.from(<String, dynamic>{}), isNull);
      expect(
        RunPlace.from(<String, dynamic>{'pullRequest': 'https://github.com/owner/repo/pull/3', 'ownPullRequest': true}),
        isNull,
      );
      expect(task('odd', workspace: 'foreign', place: {'gatePush': 'not a record'}).place, isNull);
    });

    // Harm: a kind of workspace a newer machine adds is dropped or crashes the row instead of being kept.
    test('an unknown kind of workspace is kept as the machine says it', () {
      expect(task('x', workspace: 'shared').workspace, 'shared');
      expect(task('x', workspace: 7).workspace, isNull);
    });
  });
}
