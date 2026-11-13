import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/builds.dart';

/// Holds what a task's builds say to the answer the machine gives, field by field.
void main() {
  Map<String, dynamic> aTask(Map<String, dynamic> builds) => <String, dynamic>{
    'name': 'porelo-shop-1',
    'project': 'shop',
    'securityClass': 'online',
    'state': 'Up 2 minutes',
    'running': true,
    'helpers': 2,
    ...builds,
  };

  test('a machine older than builds leaves all three absent, never empty', () {
    final task = Task.from(aTask(const {}));

    expect(task.builds, isNull);
    expect(task.buildReader, isNull);
    expect(task.buildProblem, isNull);
    expect(BuildsSaid.onTheTile(task), isNull);
  });

  test('a failed build reads every job, with the log only where one was delivered', () {
    final task = Task.from(
      aTask(<String, dynamic>{
        'buildReader': 'github',
        'buildProblem': '',
        'builds': <Map<String, dynamic>>[
          <String, dynamic>{
            'commit': '7e066aa5635c0011223344556677889900aabbcc',
            'verdict': 'failure',
            'since': '2026-10-06T12:58:00Z',
            'detail': '',
            'jobs': <Map<String, dynamic>>[
              <String, dynamic>{'name': 'Build / unit tests', 'result': 'failure', 'log': 'build-7e066aa5635c-1.log'},
              <String, dynamic>{'name': 'Build / lint', 'result': 'success', 'log': ''},
            ],
          },
        ],
      }),
    );

    expect(task.builds!.single.jobs.map((job) => job.result), ['failure', 'success']);
    final line = BuildsSaid.onTheTile(task, now: DateTime.utc(2026, 10, 6, 13, 0))!;
    expect(line.look, BuildLook.failed);
    expect(line.headline, 'Build failed');
    expect(line.detail, '7e066aa5635c · 2 jobs, 1 failed · 2 min ago');
    expect(BuildsSaid.inTheDetail(task), <String>[
      '7e066aa5635c: failure, 2 jobs, 1 failed, since 2026-10-06T12:58:00Z',
      '  Build / unit tests: failure, log in /porelo/files/build-7e066aa5635c-1.log',
      '  Build / lint: success, no log here',
    ]);
  });

  Task withBuild(String verdict, {String detail = '', String since = ''}) => Task.from(
    aTask(<String, dynamic>{
      'buildReader': 'github',
      'buildProblem': '',
      'builds': <Map<String, dynamic>>[
        <String, dynamic>{
          'commit': '0123456789abcdef',
          'verdict': verdict,
          'since': since,
          'detail': detail,
          'jobs': const <Map<String, dynamic>>[],
        },
      ],
    }),
  );

  test('the tile says passed, failed or running in a word, and anything else as it comes, grey', () {
    BuildLine said(Task task) => BuildsSaid.onTheTile(task)!;

    // A pass the machine gives without its jobs names no workflow, so it is neither green nor the build.
    expect(
      (said(withBuild('success')).look, said(withBuild('success')).headline),
      (BuildLook.none, 'The machine says passed; its workflows are not reported'),
    );
    expect((said(withBuild('queued')).look, said(withBuild('queued')).headline), (BuildLook.running, 'Build queued'));
    expect(
      (said(withBuild('running')).look, said(withBuild('running')).headline),
      (BuildLook.running, 'Build running'),
    );
    expect(
      (said(withBuild('cancelled')).look, said(withBuild('cancelled')).headline),
      (BuildLook.none, 'Build cancelled'),
    );
    expect(said(withBuild('unknown', detail: 'the vault is shut')).detail, '0123456789ab · the vault is shut');
    expect(said(withBuild('')).headline, 'Build: no verdict given');
  });

  // Harm: a push the forge will never build reads as a verdict still to come, and the person waits for a build.
  test('a push that will not be built reads so, grey, never as running, passed or failed', () {
    final none = BuildsSaid.onTheTile(withBuild('none'))!;
    expect((none.look, none.headline), (BuildLook.none, 'No build for this push'));
  });

  test('before any build, and when the reader does not work, the tile is grey and says why', () {
    final none = Task.from(
      aTask(const <String, dynamic>{'buildReader': 'github', 'buildProblem': '', 'builds': <Object>[]}),
    );
    final broken = Task.from(aTask(const <String, dynamic>{'buildReader': 'github', 'buildProblem': 'not installed'}));

    expect(
      (BuildsSaid.onTheTile(none)!.look, BuildsSaid.onTheTile(none)!.headline, BuildsSaid.onTheTile(none)!.detail),
      (BuildLook.none, 'No build yet', 'no push yet; its builds are read from github'),
    );
    expect(
      (BuildsSaid.onTheTile(broken)!.headline, BuildsSaid.onTheTile(broken)!.detail),
      ('Builds not followed', 'not installed'),
    );
  });

  test('the age is said only when the machine gave a time it can read', () {
    final now = DateTime.utc(2026, 10, 6, 13, 0);
    expect(
      BuildsSaid.onTheTile(withBuild('success', since: '2026-10-06T12:59:40Z'), now: now)!.detail,
      '0123456789ab · just now',
    );
    expect(
      BuildsSaid.onTheTile(withBuild('success', since: '2026-10-06T10:00:00Z'), now: now)!.detail,
      '0123456789ab · 3 h ago',
    );
    expect(BuildsSaid.onTheTile(withBuild('success', since: 'yesterday'), now: now)!.detail, '0123456789ab');
  });

  test('each workflow takes its own verdict from its jobs, a skipped job beside a passed one not a fault', () {
    final build = Build(
      commit: '0123456789abcdef',
      verdict: 'failure',
      jobs: const <BuildJob>[
        BuildJob(name: 'Build / unit tests', result: 'success'),
        BuildJob(name: 'Build / publish', result: 'skipped'),
        BuildJob(name: 'Acceptance / leased', result: 'in_progress'),
        BuildJob(name: 'Shared rules check / check', result: 'failure'),
        BuildJob(name: 'Nightly / all', result: 'skipped'),
        BuildJob(name: 'Docs', result: 'cancelled'),
      ],
    );

    expect(
      <(String, BuildLook, String)>[
        for (final line in BuildsSaid.workflowsOf(build)) (line.name, line.look, line.words),
      ],
      <(String, BuildLook, String)>[
        ('Build', BuildLook.passed, 'passed'),
        ('Acceptance', BuildLook.running, 'running'),
        ('Shared rules check', BuildLook.failed, 'failed'),
        ('Nightly', BuildLook.none, 'skipped'),
        ('Docs', BuildLook.none, 'cancelled'),
      ],
    );
  });

  test('a success over a workflow that did not pass is never said to be a passed build', () {
    Task over(List<BuildJob> jobs) => Task.from(
      aTask(<String, dynamic>{
        'buildReader': 'github',
        'buildProblem': '',
        'builds': <Map<String, dynamic>>[
          <String, dynamic>{
            'commit': '0123456789abcdef',
            'verdict': 'success',
            'jobs': <Map<String, dynamic>>[
              for (final job in jobs) <String, dynamic>{'name': job.name, 'result': job.result},
            ],
          },
        ],
      }),
    );

    final cancelled = BuildsSaid.onTheTile(
      over(const <BuildJob>[
        BuildJob(name: 'Build / unit tests', result: 'success'),
        BuildJob(name: 'Docs / site', result: 'cancelled'),
      ]),
    )!;
    expect((cancelled.look, cancelled.headline), (BuildLook.none, 'Not every workflow passed'));
    final withSkipped = BuildsSaid.onTheTile(
      over(const <BuildJob>[
        BuildJob(name: 'Build / unit tests', result: 'success'),
        BuildJob(name: 'Nightly / all', result: 'skipped'),
      ]),
    )!;
    expect((withSkipped.look, withSkipped.headline), (BuildLook.passed, 'Build workflow passed'));
    final both = BuildsSaid.onTheTile(
      over(const <BuildJob>[
        BuildJob(name: 'Build / unit tests', result: 'success'),
        BuildJob(name: 'Shared rules check / check', result: 'success'),
      ]),
    )!;
    expect((both.look, both.headline), (BuildLook.passed, 'Passed: every workflow that has run'));
    final skipped = BuildsSaid.onTheTile(over(const <BuildJob>[BuildJob(name: 'Nightly / all', result: 'skipped')]))!;
    expect((skipped.look, skipped.headline), (BuildLook.none, 'No workflow ran'));
  });

  test('a workflow that timed out or could not start is failed and named, whatever the verdict', () {
    Task over(String verdict, List<BuildJob> jobs) => Task.from(
      aTask(<String, dynamic>{
        'buildReader': 'github',
        'buildProblem': '',
        'builds': <Map<String, dynamic>>[
          <String, dynamic>{
            'commit': '0123456789abcdef',
            'verdict': verdict,
            'jobs': <Map<String, dynamic>>[
              for (final job in jobs) <String, dynamic>{'name': job.name, 'result': job.result},
            ],
          },
        ],
      }),
    );

    final timedOut = BuildsSaid.onTheTile(
      over('success', const <BuildJob>[
        BuildJob(name: 'Build / unit tests', result: 'timed_out'),
        BuildJob(name: 'Shared rules check / check', result: 'success'),
      ]),
    )!;
    expect((timedOut.look, timedOut.headline), (BuildLook.failed, 'Build failed'));
    final notStarted = BuildsSaid.onTheTile(
      over('cancelled', const <BuildJob>[BuildJob(name: 'Acceptance / leased', result: 'startup_failure')]),
    )!;
    expect((notStarted.look, notStarted.headline), (BuildLook.failed, 'Acceptance failed'));
  });

  test('a workflow the forge left unnamed is said by the job, never as a blank', () {
    final build = Build(
      commit: '0123456789abcdef',
      verdict: 'success',
      jobs: const <BuildJob>[
        BuildJob(name: ' / lint', result: 'success'),
        BuildJob(name: '', result: 'success'),
      ],
    );

    expect(BuildsSaid.workflowsOf(build).map((line) => line.name), <String>['/ lint', 'unnamed workflow']);
  });

  group('the runs the machine lists for a commit', () {
    Task withRuns(String verdict, Object? runs, {List<BuildJob> jobs = const <BuildJob>[]}) => Task.from(
      aTask(<String, dynamic>{
        'buildReader': 'github',
        'buildProblem': '',
        'builds': <Map<String, dynamic>>[
          <String, dynamic>{
            'commit': '0123456789abcdef',
            'verdict': verdict,
            'jobs': <Map<String, dynamic>>[
              for (final job in jobs) <String, dynamic>{'name': job.name, 'result': job.result},
            ],
            'runs': ?runs,
          },
        ],
      }),
    );

    Map<String, dynamic> run(String name, String result) => <String, dynamic>{'name': name, 'result': result};

    // The harm: a parser that throws on what it does not know takes the whole task list with it,
    // and one that drops a run leaves the failed one out of the verdict.
    test('runs are read field by field; absent or with an entry that is no run, they are unread', () {
      expect(withRuns('success', null).builds!.single.runs, isNull);
      expect(withRuns('success', 'no list').builds!.single.runs, isNull);
      expect(withRuns('success', <Object?>[run('Build', 'success'), 'no run']).builds!.single.runs, isNull);
      final odd = withRuns('success', <Object?>[
        <String, dynamic>{'name': 7, 'result': null, 'attempt': 2},
      ]).builds!.single.runs!.single;
      expect((odd.name, odd.result), ('', ''));
      final read = withRuns('success', <Object?>[run('Build', 'in_progress')]).builds!.single.runs!.single;
      expect((read.name, read.result), ('Build', 'in_progress'));
    });

    // The harm: the jobs the forge listed so far all passed, and the workflow that failed after
    // them is not in them, so the tile says passed.
    test('a failed run is named as failed, whatever the jobs and the verdict say', () {
      final said = BuildsSaid.onTheTile(
        withRuns(
          'success',
          <Object?>[run('Build', 'success'), run('Acceptance', 'failure')],
          jobs: const <BuildJob>[BuildJob(name: 'Build / unit tests', result: 'success')],
        ),
      )!;

      expect((said.look, said.headline), (BuildLook.failed, 'Acceptance failed'));
      expect(said.workflows.map((line) => (line.name, line.look)), <(String, BuildLook)>[
        ('Build', BuildLook.passed),
        ('Acceptance', BuildLook.failed),
      ]);
    });

    // The harm: a workflow still queued or running is not in the jobs yet, and the tile says passed
    // before it has ended.
    test('a run not finished keeps the tile from saying passed', () {
      for (final unfinished in <String>['queued', 'in_progress']) {
        final said = BuildsSaid.onTheTile(
          withRuns(
            'success',
            <Object?>[run('Build', 'success'), run('Acceptance', unfinished)],
            jobs: const <BuildJob>[BuildJob(name: 'Build / unit tests', result: 'success')],
          ),
        )!;

        expect(said.look, isNot(BuildLook.passed), reason: unfinished);
        expect(said.workflows.last.look, BuildLook.running, reason: unfinished);
      }
    });

    // The harm: a result this interface does not know, or none, is counted as a pass.
    test('a result not known here is shown as the forge says it, and is no pass', () {
      final said = BuildsSaid.onTheTile(
        withRuns('success', <Object?>[run('Build', 'success'), run('Deploy', 'action_required'), run('Docs', '')]),
      )!;

      expect(said.look, isNot(BuildLook.passed));
      expect(said.workflows.map((line) => line.words), <String>['passed', 'action_required', 'no result given']);
    });

    // The harm: a commit no workflow ran on is said to have passed.
    test('runs listed and empty say no workflow ran, never passed', () {
      final said = BuildsSaid.onTheTile(withRuns('success', const <Object?>[]))!;

      expect((said.look, said.headline), (BuildLook.none, 'No workflow ran'));
      expect(said.workflows, isEmpty);
    });

    // The harm: a reading that failed, or one not yet made, reads as a commit no workflow ran on.
    // Harm: a push the forge will never build reads as a workflow that did not run, a verdict still to come.
    test('a push that will not be built reads so beside runs listed empty', () {
      final listed = BuildsSaid.onTheTile(withRuns('none', const <Object?>[]))!;
      expect((listed.look, listed.headline), (BuildLook.none, 'No build for this push'));
    });

    test('no runs beside a verdict that is not final keeps that verdict, never no workflow ran', () {
      final unknown = BuildsSaid.onTheTile(withRuns('unknown', const <Object?>[]))!;
      final queued = BuildsSaid.onTheTile(withRuns('queued', const <Object?>[]))!;

      expect(unknown.headline, isNot('No workflow ran'));
      expect(queued.headline, isNot('No workflow ran'));
      expect(queued.look, BuildLook.running);
    });

    test('every run passed says so, one line per run, and two runs of one name both stand', () {
      final said = BuildsSaid.onTheTile(
        withRuns('success', <Object?>[run('Build', 'success'), run('Build', 'success'), run('Docs', 'success')]),
      )!;

      expect(said.look, BuildLook.passed);
      expect(said.workflows.map((line) => line.name), <String>['Build', 'Build', 'Docs']);
    });

    // The harm: the runs all passed while the machine still says the build is running or failed.
    test('every run passed beside a verdict that is not success is no pass', () {
      for (final verdict in <String>['running', 'failure', 'unknown']) {
        final said = BuildsSaid.onTheTile(withRuns(verdict, <Object?>[run('Build', 'success')]))!;

        expect(said.look, isNot(BuildLook.passed), reason: verdict);
      }
    });
  });
}
