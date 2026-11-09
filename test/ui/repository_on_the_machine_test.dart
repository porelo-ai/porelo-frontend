import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/host_progress.dart';
import 'package:porelo_frontend/src/ui/machine_tree.dart';

/// What the host said of project `demo` in its `org status`, with [repositories] as it lists them.
HostProjectProgress _said({
  String state = 'carried',
  String? why,
  List<Map<String, Object?>> repositories = const [],
}) => HostProgress.read(
  jsonEncode({
    'projects': [
      {'project': 'demo', 'state': state, 'why': ?why, 'repositories': repositories},
    ],
  }),
).of('demo')!;

String _row({
  String repository = 'core',
  HostProjectProgress? progress,
  bool progressRead = true,
  List<Task>? tasks = const [],
  List<String>? carriedAlone,
  Repository? listed,
}) => repositoryOnTheMachine(
  project: 'demo',
  repository: repository,
  progress: progress,
  progressRead: progressRead,
  tasks: tasks,
  carriedAlone: carriedAlone,
  listed: listed,
);

void main() {
  // Harm: the daemon's older up to date hides what the host says now, commits ahead of central, and they are lost.
  test('an up to date from the daemon never hides the host saying it is ahead of central', () {
    final words = _row(
      progress: _said(
        repositories: [
          {
            'repository': 'core',
            'state': 'taken',
            'central': {'state': 'ahead', 'commits': 2},
          },
        ],
      ),
      listed: const Repository(name: 'core', carriedHere: true, central: 'up-to-date', tasks: 0, running: 0),
    );
    expect(words, contains('2 commits ahead of central'));
    expect(words, isNot(contains('at central')));
  });

  // Harm: an up to date from the host hides the daemon saying central moved on.
  test('an up to date from the host never hides the daemon saying central moved on', () {
    final words = _row(
      progress: _said(
        repositories: [
          {
            'repository': 'core',
            'state': 'taken',
            'central': {'state': 'up-to-date'},
          },
        ],
      ),
      listed: const Repository(name: 'core', carriedHere: true, central: 'moved-on', tasks: 0, running: 0),
    );
    expect(words, contains('central moved on'));
    expect(words, isNot(contains('at central')));
  });

  // Harm: a repository the machine does not carry reads as held there, as if its work waited on it.
  test('a repository the machine does not carry is said so, though the project is held', () {
    final words = _row(
      progress: _said(state: 'held', why: 'core'),
      listed: const Repository(name: 'docs', carriedHere: false, tasks: 0, running: 0),
      repository: 'docs',
    );
    expect(words, startsWith('not carried here'));
  });

  // Harm: what the organization planned reads as what the machine carries, though nobody reported it.
  test('a repository planned for the machine alone is not said to be carried there when nothing was read', () {
    final words = _row(progressRead: false, carriedAlone: ['core']);
    expect(words, isNot(contains('carried here alone')));
    expect(words, contains('not read'));
  });

  // Harm: ahead by none reads as a count, which says nothing waits though the machine says it is ahead.
  test('ahead of central by a count of none is said as a count not reported', () {
    final words = centralWords(
      const Repository(name: 'core', central: 'ahead', ahead: 0, aheadMeasured: '2026-11-09T08:00:00Z'),
    );
    expect(words, 'ahead of central, by how much not reported');
  });

  // Harm: work nobody counted reads as no task running.
  group('work the machine did not count is never no task running', () {
    test('a repository only the host names', () {
      expect(
        _row(
          repository: 'docs',
          progress: _said(
            repositories: [
              {'repository': 'docs', 'state': 'taken'},
            ],
          ),
        ),
        allOf(isNot(contains('no task running')), contains('tasks: not reported')),
      );
    });

    test('a repository the daemon counts only half of', () {
      expect(
        _row(listed: const Repository(name: 'core', carriedHere: true, tasks: 2)),
        allOf(isNot(contains('no task running')), contains('tasks: not reported')),
      );
    });

    test('a repository the daemon says it does not carry, with no count', () {
      expect(
        repositoryOnAMachine(
          project: 'demo',
          listed: const Repository(name: 'core', carriedHere: false),
          carried: false,
          tasks: const [],
        ),
        allOf(isNot(contains('no task running')), contains('tasks: not reported')),
      );
    });

    test('a repository an older daemon lists, with no count, keeps its list of work', () {
      expect(_row(listed: const Repository(name: 'core')), contains('no task running'));
    });
  });
}
