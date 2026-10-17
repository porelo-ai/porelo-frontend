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

    expect((said(withBuild('success')).look, said(withBuild('success')).headline), (BuildLook.passed, 'Build passed'));
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
}
