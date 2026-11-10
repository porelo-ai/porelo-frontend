import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_host/porelo_host.dart' show HostCardSsh;
import 'package:porelo_frontend/src/app/attention.dart';
import 'package:porelo_frontend/src/app/host_pull_requests.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';

import '../features/support/world.dart';

const _key = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

/// The host `build`, its forge forwarded to this computer at port 3000.
final _build = Machine.fromHostCard(
  HostCardSsh(
    name: 'build',
    address: 'build.example.org',
    sshPort: 22,
    hostKey: _key,
    login: 'hana',
    publicKey: _key,
    webPort: 3000,
  ),
  socketPath: '/tmp/build.sock',
  sshConfig: '/tmp/build.config',
);

/// `foo`, whose repository `foo-1` the host carries, and `bar`, of which it is no host.
List<Project> _projects() => <Project>[
  Project.from(const <String, dynamic>{
    'name': 'foo',
    'file': '/srv/foo/project.yml',
    'repositories': <Map<String, dynamic>>[
      <String, dynamic>{
        'name': 'foo-1',
        'own': true,
        'upstream': 'http://127.0.0.1:3001/foo/foo-1.git',
        'carriedHere': true,
      },
    ],
  }),
  Project.from(const <String, dynamic>{
    'name': 'bar',
    'file': '/srv/bar/project.yml',
    'repositories': <Map<String, dynamic>>[
      <String, dynamic>{'name': 'bar', 'own': true, 'upstream': 'git@example.org:acme/bar.git'},
    ],
  }),
];

HostPullRequest _request(int number, {String state = 'open', String repository = 'foo-1'}) => HostPullRequest(
  repository: repository,
  number: number,
  title: 'Make the parser strict',
  head: '0123456789abcdef0123456789abcdef01234567',
  author: 'Agent Pi <pi@example.org>',
  committer: 'Hana <hana@example.org>',
  trailers: const <String>['Assisted-by: Claude Code, claude-opus-5-5'],
  state: state,
);

Future<void> _until(bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  late FakeBackend backend;
  late Attention attention;

  setUp(() async {
    final askAgainAfter = HostPullRequests.askAgainAfter;
    HostPullRequests.askAgainAfter = const Duration(milliseconds: 20);
    addTearDown(() => HostPullRequests.askAgainAfter = askAgainAfter);
    backend = FakeBackend(const <Task>[])..theProjectsItHas = _projects();
    final settings = Settings(MemorySettingsStore());
    final elsewhere = FakeBackend(const <Task>[])..nodeId = 'this-computer';
    final machines = Machines(
      settings,
      reach: (machine) => machine.hostCard != null ? backend : elsewhere,
      tunnels: FakeTunnels(),
    );
    attention = Attention(machines);
    addTearDown(() async {
      attention.dispose();
      machines.dispose();
      settings.dispose();
      await backend.stop();
      await elsewhere.stop();
    });
    await machines.add(_build);
    for (final machine in machines.all) {
      await machines.of(machine).untilAsked();
    }
    await _until(() => backend.pullRequestWatches.isNotEmpty);
  });

  List<AttentionRow> rows(AttentionKind kind) => attention.openRows.where((row) => row.kind == kind).toList();

  // Harm: a pull request waiting for the person's merge on a host forge is never said, or one of a project the
  // machine is no host of is asked for and refused in the person's face.
  test('each open pull request of a carried project is one row naming its one action', () async {
    expect(backend.pullRequestWatches.map((watch) => watch.project), <String>['foo']);
    backend.pullRequestWatches.single.answer(<HostPullRequest>[_request(1), _request(2)]);
    await _until(() => rows(AttentionKind.pullRequest).length == 2);

    final row = rows(AttentionKind.pullRequest).first.value as PullRequestRow;
    expect(row.project.name, 'foo');
    expect(row.request.number, 1);
    expect(row.action, contains('Pull request 1 of foo-1 waits for your approval and merge'));
    expect(row.stale, isFalse);
  });

  // Harm: the window opens some other address than the pull request on the host's own forge forward, or one built
  // from a number or a path that names nothing.
  test("a pull request opens on the host's forge forward, at its repository's path and its number", () {
    final foo = _projects().first;
    expect(
      pullRequestAddress(forge: _build.hostCard!.forgeUrl, project: foo, request: _request(1)),
      Uri.parse('http://build.localhost:3000/foo/foo-1/pulls/1'),
    );
    expect(pullRequestAddress(forge: _build.hostCard!.forgeUrl, project: foo, request: _request(0)), isNull);
    expect(pullRequestAddress(forge: _build.hostCard!.forgeUrl, project: foo, request: _request(-3)), isNull);
    expect(
      pullRequestAddress(forge: null, project: foo, request: _request(1)),
      isNull,
      reason: 'no forge forward',
    );
    expect(
      pullRequestAddress(
        forge: _build.hostCard!.forgeUrl,
        project: foo,
        request: _request(1, repository: 'gone'),
      ),
      isNull,
      reason: 'a repository the project does not name has no path',
    );
    final unsaid = Project.from(const <String, dynamic>{
      'name': 'foo',
      'repositories': <Map<String, dynamic>>[
        <String, dynamic>{'name': 'foo-1', 'upstream': 'http://127.0.0.1:3001/foo/..'},
      ],
    });
    expect(pullRequestAddress(forge: _build.hostCard!.forgeUrl, project: unsaid, request: _request(1)), isNull);
  });

  // Harm: a merged or closed pull request keeps asking the person for a merge that already happened.
  test('a row closes itself when the watch says its pull request ended', () async {
    final watch = backend.pullRequestWatches.single;
    watch.answer(<HostPullRequest>[_request(1)]);
    await _until(() => rows(AttentionKind.pullRequest).isNotEmpty);

    // Left out of a list without an end: absence alone is not an end.
    watch.answer(const <HostPullRequest>[]);
    await _until(() => (rows(AttentionKind.pullRequest).single.value as PullRequestRow).stale);
    expect((rows(AttentionKind.pullRequest).single.value as PullRequestRow).stale, isTrue);

    watch.answer(const <HostPullRequest>[], ended: <HostPullRequest>[_request(1, state: 'merged')]);
    await _until(() => rows(AttentionKind.pullRequest).isEmpty);

    expect(rows(AttentionKind.pullRequest), isEmpty);
    expect(attention.recentlyResolved.map((each) => each.row.kind), contains(AttentionKind.pullRequest));
  });

  // Harm: a lost forge or an unreadable mirror reads as every pull request closed, so a merge nobody made is no
  // longer asked for.
  test('a watch that ends with an error keeps its rows, stale, and is asked again', () async {
    final first = backend.pullRequestWatches.single;
    first.answer(<HostPullRequest>[_request(1)]);
    await _until(() => rows(AttentionKind.pullRequest).isNotEmpty);

    first.fail(const VarlinkException('org.fuin.porelo.Tasks1.Unexpected'));
    await _until(() => backend.pullRequestWatches.length == 2);

    final kept = rows(AttentionKind.pullRequest).single.value as PullRequestRow;
    expect(kept.request.number, 1);
    expect(kept.stale, isTrue);
    expect(backend.pullRequestWatches.length, 2, reason: 'the window asks again');

    backend.pullRequestWatches.last.answer(<HostPullRequest>[_request(1)]);
    await _until(() => !(rows(AttentionKind.pullRequest).single.value as PullRequestRow).stale);
    expect((rows(AttentionKind.pullRequest).single.value as PullRequestRow).stale, isFalse);
  });

  // Harm: the person is shown the daemon's token instead of what to do, or a missing token goes unsaid and no pull
  // request ever shows.
  test('a missing forge token and a refused read are one row each, in words', () async {
    backend.pullRequestWatches.single.fail(
      MissingHostForgeToken(
        const VarlinkException('org.fuin.porelo.Tasks1.MissingHostForgeToken', <String, dynamic>{
          'credential': 'forge.person',
          'storeCommand': <String>['porelo', 'host', 'forge-token'],
        }),
      ),
    );
    await _until(() => rows(AttentionKind.pullRequestsRefused).isNotEmpty);

    final missing = rows(AttentionKind.pullRequestsRefused).single.value as PullRequestsRefusedRow;
    expect(missing.words, isNot(contains('MissingHostForgeToken')));
    expect(missing.words, contains('forge token'));
    expect(missing.storeCommand, 'porelo host forge-token');

    await _until(() => backend.pullRequestWatches.length == 2);
    backend.pullRequestWatches.last.fail(
      HostPullRequestsRefused(
        const VarlinkException('org.fuin.porelo.Tasks1.HostPullRequestsRefused', <String, dynamic>{
          'reason': 'vault-unreadable',
          'message': 'the vault is locked or unreadable; unlock or repair it before reading reviews',
        }),
      ),
    );
    await _until(
      () => (rows(AttentionKind.pullRequestsRefused).single.value as PullRequestsRefusedRow).storeCommand == null,
    );

    final refused = rows(AttentionKind.pullRequestsRefused).single.value as PullRequestsRefusedRow;
    expect(refused.words, isNot(contains('vault-unreadable')));
    expect(refused.words, contains('vault'));
    expect(refused.words, contains('unlock or repair it'));
    expect(refused.storeCommand, isNull);
  });
}
