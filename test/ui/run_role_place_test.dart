import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../features/support/tiles.dart';
import '../features/support/world.dart';

/// What a run's row says of its role and place, read from the machine's task record.
void main() {
  Task task(String name, {Object? role, Object? place}) => Task.from(<String, dynamic>{
    'name': 'porelo-walk_$name',
    'task': name,
    'project': 'walk',
    'running': true,
    'mode': 'UNATTENDED',
    'role': ?role,
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

  // Harm: a person cannot tell which run reviews which pull request, and decides or stops the wrong one.
  testWidgets('a reviewer and an author each say their role and place on the row', (tester) async {
    await onTheWork(tester, [
      task('reviewer', role: 'REVIEWER', place: {'pullRequest': 'https://github.com/owner/repo/pull/17'}),
      task(
        'author',
        role: 'AUTHOR',
        place: {
          'gatePush': {'name': 'author'},
        },
      ),
    ]);
    expect(run('as reviewer at pull request owner/repo#17'), findsOneWidget);
    expect(run('as author at the gate push author'), findsOneWidget);
  });

  // Harm: a role or place made up where the machine said none is believed.
  testWidgets('a task the machine names no role or place for says neither', (tester) async {
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
      expect(task('odd', role: 'REVIEWER', place: {'gatePush': 'not a record'}).place, isNull);
    });

    // Harm: a role a newer machine adds is dropped or crashes the row instead of being shown.
    test('an unknown role is kept as the machine says it', () {
      expect(task('x', role: 'OBSERVER').role, 'OBSERVER');
      expect(task('x', role: 7).role, isNull);
    });
  });
}
