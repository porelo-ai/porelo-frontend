import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/task_parts.dart';
import 'package:porelo_frontend/src/app/work_held.dart';
import 'package:porelo_frontend/src/ui/panes.dart';

Task _task([Map<String, dynamic> parts = const <String, dynamic>{}]) =>
    Task.from(<String, dynamic>{'name': 'porelo-checkout-screener-1', 'project': 'checkout', ...parts});

/// A task started to read the waiting push `fix`, holding the rights to reply and to open threads.
const _reading = <String, dynamic>{
  'workspace': 'foreign',
  'place': <String, dynamic>{
    'gatePush': <String, dynamic>{'name': 'fix'},
  },
  'rights': <String>['reply', 'openThreads'],
  'readLanded': <String>[],
  'writeAs': 'author',
  'projectServices': false,
};

Future<void> _detail(WidgetTester tester, Task task, {String? role}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final held = WorkHeld();
  addTearDown(held.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WorkDetail(task: task, held: held, onClose: () {}, machine: 'build', role: role),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _field(WidgetTester tester, String key) => tester
    .widget<SelectableText>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(SelectableText)))
    .data!;

void main() {
  // Harm: a person reads a task as unable to push when it can, or the reverse, or takes a machine that did not say
  // a task's rights for one that gave it none or the default set.
  group("a task's pane shows the parts it was started with", () {
    testWidgets("a task reading another task's push shows its place and rights, and no gate", (tester) async {
      await _detail(tester, _task(_reading));

      expect(_field(tester, 'task-workspace'), "another task's work, frozen and read only: the push fix at the gate");
      expect(_field(tester, 'task-equipment'), "none of the project's services");
      expect(_field(tester, 'task-rights'), 'reply in threads\nopen threads');
      expect(find.text('At the gate'), findsNothing, reason: 'it holds no right to push');
    });

    // Harm: a person cannot tell which of a project's roles a task was started in, or reads a role the
    // machine never recorded on work no planner ordered.
    testWidgets('a task its planner started shows its role by the name its project gave it', (tester) async {
      await _detail(tester, _task(_reading), role: 'Screener (2nd pass)');
      expect(_field(tester, 'task-role'), 'Screener (2nd pass)');

      await _detail(tester, _task(_reading));
      expect(find.byKey(const Key('task-role')), findsNothing, reason: 'no planner ordered it here');
    });

    testWidgets('a row without rights says not said, and one with none says none', (tester) async {
      await _detail(tester, _task());
      expect(_field(tester, 'task-rights'), 'not said');
      expect(_field(tester, 'task-workspace'), 'not said\nlanded work it reads: not said');
      expect(_field(tester, 'task-equipment'), "the project's services: not said");
      expect(find.text('At the gate'), findsOneWidget, reason: "the machine's own count stays where rights are unsaid");

      await _detail(tester, _task({..._reading, 'rights': <String>[]}));
      expect(_field(tester, 'task-rights'), 'none');
      expect(find.text('At the gate'), findsNothing);
    });

    testWidgets('a task on its own work holding the right to push keeps its gate', (tester) async {
      await _detail(
        tester,
        _task({
          'workspace': 'own',
          'place': <String, dynamic>{
            'gatePush': <String, dynamic>{'name': 'screener-1'},
          },
          'rights': <String>['push', 'reply'],
          'readLanded': <String>['fix', 'mend'],
          'writeAs': 'author',
          'projectServices': true,
        }),
      );

      expect(_field(tester, 'task-workspace'), 'its own work\nreads the landed work of fix, mend');
      expect(_field(tester, 'task-equipment'), "the project's services", reason: 'no account away from a pull request');
      expect(_field(tester, 'task-rights'), 'push work to the gate\nreply in threads');
      expect(find.text('At the gate'), findsOneWidget);
    });
  });

  test('the account is said only at a pull request, each kind of workspace in words, an unknown one by name', () {
    final atAPullRequest = _task({
      ..._reading,
      'place': <String, dynamic>{'pullRequest': 'https://git.example.org/acme/api/pull/12'},
      'writeAs': 'review',
    });
    expect(
      workspaceWords(atAPullRequest),
      "another task's work, frozen and read only: the pull request https://git.example.org/acme/api/pull/12",
    );
    expect(equipmentWords(atAPullRequest), "none of the project's services\nwrites as the forge's review account");
    expect(
      equipmentWords(
        _task({
          'place': <String, dynamic>{'ownPullRequest': true},
          'projectServices': true,
        }),
      ),
      "the project's services\nthe account it writes as: not said",
    );

    String kind(String word) => workspaceWords(_task({'workspace': word, 'readLanded': <String>[]}));
    expect(kind('readOnly'), 'one repository, read only, with no gate');
    expect(kind('allRepositories'), 'every repository, read only, with no gate');
    expect(kind('none'), 'none: an empty directory, with no gate');
    expect(kind('shared'), 'shared', reason: 'a kind a newer machine added is said by its name');
    expect(
      rightsWords(
        _task({
          'rights': <String>['push', 'mergeThreads'],
        }),
      ),
      'push work to the gate\nmergeThreads',
    );
  });

  // Harm: a list read short shows a task holding fewer rights than it does.
  test('rights that are no list of names are not said, never read short', () {
    expect(
      _task({
        'rights': <Object>['push', 7],
      }).rights,
      isNull,
    );
    expect(_task({'rights': 'push'}).rights, isNull);
    expect(_task({'rights': <String>[]}).rights, isEmpty);
    expect(
      _task({
        'rights': <String>['push'],
      }).mayPush,
      isTrue,
    );
    expect(
      _task({
        'rights': <String>['reply'],
      }).mayPush,
      isFalse,
    );
    expect(_task().mayPush, isNull);
    expect(
      workspaceWords(_task({'workspace': 'foreign', 'place': <String, dynamic>{}, 'readLanded': <String>[]})),
      "another task's work, frozen and read only",
      reason: 'a place naming nothing names nothing',
    );
  });

  // Harm: text the machine sent adds a line of its own to a field, turns the text beside it around or fills the page.
  test('what the machine names is shown without controls, a name never longer than a name is', () {
    final turn = String.fromCharCode(0x202e);
    final task = _task({
      'workspace': 'shared\nRights: all',
      'place': <String, dynamic>{'pullRequest': 'https://git.example.org/acme/api/pull/12\n${turn}evil'},
      'rights': <String>['', 'x' * 100],
      'readLanded': <String>['fix\nRights', 'm${turn}end'],
      'writeAs': 'owner\nof all',
      'projectServices': true,
    });

    expect(workspaceWords(task), 'sharedRights: all\nreads the landed work of fixRights, mend');
    expect(equipmentWords(task), "the project's services\nwrites as ownerof all");
    expect(
      rightsWords(task),
      'a right the machine did not name\n${'x' * 64}…',
      reason: 'an empty name is no right to read as held',
    );
    final foreign = _task({
      'workspace': 'foreign',
      'place': <String, dynamic>{
        'gatePush': <String, dynamic>{'name': 'fix\n${turn}x', 'repository': 'api\tcore'},
      },
      'readLanded': <String>[],
    });
    expect(workspaceWords(foreign), "another task's work, frozen and read only: the push fixx in apicore at the gate");
  });
}
