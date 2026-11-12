import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_host/porelo_host.dart' show HostCardSsh;
import 'package:porelo_frontend/src/app/attention.dart';
import 'package:porelo_frontend/src/app/fleet_model.dart';
import 'package:porelo_frontend/src/app/host_pull_requests.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';

import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/app/links.dart';
import 'package:porelo_frontend/src/app/organization_source.dart' show HostConnections, OrganizationRefused;

import '../features/support/world.dart';
import '../support/organization_fixtures.dart';

/// Connections to `build` whose forge gives no answer through its forward, until it is raised anew.
class _SilentForge extends FixtureConnections {
  _SilentForge(this.said) : super(<String>['build']);

  final List<String> said;

  @override
  Future<bool?> forgeAnswers(String host) async => false;

  @override
  Future<void> raiseForwardAnew(String host) async => said.add('raise $host');
}

/// A forge that gives no answer and whose forward is refused when raised anew.
class _RefusedForge extends _SilentForge {
  _RefusedForge(super.said);

  @override
  Future<void> raiseForwardAnew(String host) async {
    said.add('raise $host');
    throw const OrganizationRefused('[::1]:3000 is held by another program.');
  }
}

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
  late Machines machines;

  FleetModel build() => machines.of(machines.all.firstWhere((machine) => machine.hostCard != null));

  setUp(() async {
    final askAgainAfter = HostPullRequests.askAgainAfter;
    HostPullRequests.askAgainAfter = const Duration(milliseconds: 20);
    addTearDown(() => HostPullRequests.askAgainAfter = askAgainAfter);
    backend = FakeBackend(const <Task>[])..theProjectsItHas = _projects();
    final settings = Settings(MemorySettingsStore());
    final elsewhere = FakeBackend(const <Task>[])..nodeId = 'this-computer';
    machines = Machines(
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
    for (final upstream in <String>['http://127.0.0.1:3001', 'https://forge.example.org/', 'foo-1', ':foo-1']) {
      final named = Project.from(<String, dynamic>{
        'name': 'foo',
        'repositories': <Map<String, dynamic>>[
          <String, dynamic>{'name': 'foo-1', 'upstream': upstream},
        ],
      });
      expect(
        pullRequestAddress(forge: _build.hostCard!.forgeUrl, project: named, request: _request(1)),
        isNull,
        reason: '$upstream names no repository',
      );
    }
    final scp = Project.from(const <String, dynamic>{
      'name': 'foo',
      'repositories': <Map<String, dynamic>>[
        <String, dynamic>{'name': 'foo-1', 'upstream': 'git@example.org:acme/foo-1.git'},
      ],
    });
    expect(
      pullRequestAddress(forge: _build.hostCard!.forgeUrl, project: scp, request: _request(1)),
      Uri.parse('http://build.localhost:3000/foo/foo-1/pulls/1'),
    );
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
    final resolved = attention.recentlyResolved.where((each) => each.row.kind == AttentionKind.pullRequest).single;
    expect((resolved.row.value as PullRequestRow).ended, 'merged', reason: 'resolved as the machine said it ended');
  });

  // Harm: a project the host stops carrying for a while, or stops listing, reads as its pull requests merged or
  // closed, so a merge nobody made is no longer asked for.
  test('a pull request of a project no longer carried or listed stays, stale, and is not resolved', () async {
    backend.pullRequestWatches.single.answer(<HostPullRequest>[_request(1)]);
    await _until(() => rows(AttentionKind.pullRequest).isNotEmpty);

    backend.theProjectsItHas = <Project>[
      Project.from(const <String, dynamic>{
        'name': 'foo',
        'file': '/srv/foo/project.yml',
        'repositories': <Map<String, dynamic>>[
          <String, dynamic>{'name': 'foo-1', 'own': true, 'upstream': 'http://127.0.0.1:3001/foo/foo-1.git'},
        ],
      }),
    ];
    await build().refresh(quietly: true);
    expect((rows(AttentionKind.pullRequest).single.value as PullRequestRow).stale, isTrue);

    backend.theProjectsItHas = const <Project>[];
    await build().refresh(quietly: true);
    expect((rows(AttentionKind.pullRequest).single.value as PullRequestRow).stale, isTrue);
    expect(attention.recentlyResolved.where((each) => each.row.kind == AttentionKind.pullRequest), isEmpty);
  });

  // Harm: a watch that ends without a word, or whose own connection drops while the machine answers, is never asked
  // again, and nothing says its pull requests are no longer followed.
  test('a watch that ends quietly or loses its own connection is said and asked again', () async {
    backend.pullRequestWatches.single.end();
    await _until(() => backend.pullRequestWatches.length == 2);
    expect(backend.pullRequestWatches.length, 2);
    expect(rows(AttentionKind.pullRequestsRefused), hasLength(1), reason: 'an ended watch is said');

    backend.pullRequestWatches.last.fail(const VarlinkDisconnected('its socket closed'));
    await _until(() => backend.pullRequestWatches.length == 3);
    expect(backend.pullRequestWatches.length, 3);

    backend.pullRequestWatches.last.answer(const <HostPullRequest>[]);
    await _until(() => rows(AttentionKind.pullRequestsRefused).isEmpty);
    expect(rows(AttentionKind.pullRequestsRefused), isEmpty);
  });

  // Harm: a person who stored the missing token waits out the whole pause before refreshing shows anything.
  test('refreshing the machine asks a refused watch again at once', () async {
    HostPullRequests.askAgainAfter = const Duration(hours: 1);
    backend.pullRequestWatches.single.fail(
      MissingHostForgeToken(const VarlinkException('org.fuin.porelo.Tasks1.MissingHostForgeToken')),
    );
    await _until(() => rows(AttentionKind.pullRequestsRefused).isNotEmpty);

    await build().refresh(quietly: true);
    await _until(() => backend.pullRequestWatches.length == 2);
    expect(backend.pullRequestWatches.length, 2);
  });

  // Harm: a store command from a faulty machine carries what breaks out of a terminal's paste, or is copied cut short
  // or unquoted, or the words point at a command that is not there.
  test('a store command is quoted, refused whole when any word is unsafe, and the words follow it', () {
    PullRequestsRefusedRow withCommand(List<Object?> words) => PullRequestsRefusedRow(
      machine: _build,
      project: 'foo',
      refusal: MissingHostForgeToken(
        VarlinkException('org.fuin.porelo.Tasks1.MissingHostForgeToken', <String, dynamic>{
          'credential': 'forge.person',
          'storeCommand': words,
        }),
      ),
    );
    final quoted = withCommand(<String>['porelo', 'host', 'forge-token', 'my forge']);
    expect(quoted.storeCommand, "porelo host forge-token 'my forge'");
    expect(quoted.words, contains('command below'));
    for (final unsafe in <List<Object?>>[
      <String>['porelo', 'host', '\x1b[201~', 'evil'],
      <String>['porelo', 'host\nevil'],
      <String>['porelo', 'host\u2028evil'],
      <Object?>['porelo', 7],
      <String>['porelo', ''],
      <String>[],
    ]) {
      final refused = withCommand(unsafe);
      expect(refused.storeCommand, isNull, reason: '$unsafe');
      expect(refused.words, isNot(contains('command below')), reason: '$unsafe');
      expect(refused.words, contains('no forge token of yours'));
    }
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

  // Harm: a pull request is opened through a forward that leads nowhere, where Open its forge would have raised it.
  test("opening a pull request raises the forge's forward anew first, where the forge gives no answer", () async {
    final said = <String>[];
    final previous = openLink;
    openLink = (address) async => said.add('open $address');
    addTearDown(() => openLink = previous);
    final connections = _SilentForge(said);
    addTearDown(connections.dispose);

    await openOnHostForge(
      Uri.parse('http://build.localhost:3000/foo/foo-1/pulls/1'),
      host: 'build',
      connections: connections,
    );

    expect(said, <String>['raise build', 'open http://build.localhost:3000/foo/foo-1/pulls/1']);
  });

  // Harm: the forward was cancelled and only partly raised again, and the browser sends the person's sign-in to
  // whatever program took the port meanwhile.
  test('a pull request or the forge is not opened where its forward could not be raised anew', () async {
    final said = <String>[];
    final previous = openLink;
    openLink = (address) async => said.add('open $address');
    addTearDown(() => openLink = previous);
    final connections = _RefusedForge(said);
    addTearDown(connections.dispose);

    final pull = await openOnHostForge(
      Uri.parse('http://build.localhost:3000/foo/foo-1/pulls/1'),
      host: 'build',
      connections: connections,
    );
    final forge = await openHostForge(host: 'build', connections: connections);

    expect(said, <String>['raise build', 'raise build']);
    expect(pull, contains('held by another program'));
    expect(forge, contains('held by another program'));
  });

  // Harm: a pull request is offered while the connection that reaches its forge is down, and opens nothing.
  test('a pull request is not offered while the connection to its host is down', () {
    final row = PullRequestRow(machine: _build, project: _projects().first, request: _request(1), stale: false);
    final HostConnections down = FixtureConnections();
    final HostConnections up = FixtureConnections(<String>['build']);
    addTearDown(down.dispose);
    addTearDown(up.dispose);
    expect(whyPullRequestCannotOpen(row, down), contains('Connect first'));
    expect(whyPullRequestCannotOpen(row, up), isNull);
    expect(whyPullRequestCannotOpen(row, null), isNull, reason: 'where no connections are held, its address is all');
  });
}
