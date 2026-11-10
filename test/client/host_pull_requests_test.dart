// Linux only: it stands the mock daemon on a unix socket, and on GitHub's Windows runner a test
// through it hung where no timeout could end it.
@Tags(<String>['linux'])
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/mock/mock_daemon.dart';

/// A host forge's open pull requests, as a machine reads them with the person's forge token and as it refuses.
void main() {
  late MockDaemon daemon;

  setUp(() async {
    daemon = MockDaemon();
    await daemon.start();
  });

  tearDown(() => daemon.stop());

  Future<PoreloClient> connect() => PoreloClient.connect(Backend(socketPath: daemon.socketPath, label: 'mock'));

  const head = '0123456789abcdef0123456789abcdef01234567';
  Map<String, dynamic> row(int number, {String state = 'open'}) => <String, dynamic>{
    'repository': 'foo-1',
    'number': number,
    'title': 'Make the parser strict',
    'head': head,
    'author': 'Agent Pi <pi@example.org>',
    'committer': 'Hana <hana@example.org>',
    'trailers': <String>['Assisted-by: Claude Code, claude-opus-5-5'],
    'state': state,
  };

  // Harm: a pull request read wrong opens another one on the forge, or names makers the commit does not have.
  test('a pull request is read field by field, for the project asked, open and ended apart', () async {
    final asked = <Map<String, dynamic>>[];
    daemon.method('PullRequests', (parameters) {
      asked.add(parameters);
      return <String, dynamic>{
        'pullRequests': <Map<String, dynamic>>[row(1)],
        'ended': <Map<String, dynamic>>[row(2, state: 'merged')],
      };
    });

    final seen = await (await connect()).pullRequests('foo');

    expect(asked.single, <String, dynamic>{'project': 'foo'});
    final open = seen.open.single;
    expect(open.repository, 'foo-1');
    expect(open.number, 1);
    expect(open.title, 'Make the parser strict');
    expect(open.head, head);
    expect(open.author, 'Agent Pi <pi@example.org>');
    expect(open.committer, 'Hana <hana@example.org>');
    expect(open.trailers, <String>['Assisted-by: Claude Code, claude-opus-5-5']);
    expect(open.state, 'open');
    expect(seen.ended.single.number, 2);
    expect(seen.ended.single.state, 'merged');
  });

  // Harm: makers a machine did not report read as none, which the trailer check would then judge.
  test('makers the machine leaves out are absent, never empty', () {
    final read = HostPullRequest.from(<String, dynamic>{'repository': 'foo-1', 'number': 3, 'author': ''});
    expect(read.author, isNull);
    expect(read.committer, isNull);
    expect(read.trailers, isNull);
    expect(HostPullRequest.from(<String, dynamic>{'trailers': <Object>[]}).trailers, isEmpty);
  });

  // Harm: the watch's changes are lost, so a merged pull request still asks the person for a merge.
  test('the watch answers every change, its ended rows with it', () async {
    final changes = StreamController<Map<String, dynamic>>();
    addTearDown(changes.close);
    final asked = <Map<String, dynamic>>[];
    daemon.pushes('WatchPullRequests', (parameters) {
      asked.add(parameters);
      return changes.stream;
    });

    final seen = <PullRequestsSeen>[];
    final watching = (await connect()).watchPullRequests('foo').listen(seen.add);
    addTearDown(watching.cancel);
    changes.add(<String, dynamic>{
      'pullRequests': <Map<String, dynamic>>[row(1)],
      'ended': <Object>[],
    });
    changes.add(<String, dynamic>{
      'pullRequests': <Object>[],
      'ended': <Map<String, dynamic>>[row(1, state: 'closed')],
    });
    await _until(() => seen.length == 2);

    expect(asked.single, <String, dynamic>{'project': 'foo'});
    expect(seen.first.open.single.number, 1);
    expect(seen.last.open, isEmpty);
    expect(seen.last.ended.single.state, 'closed');
  });

  // Harm: a missing token or a refused read reaches the window as a raw error, so the person is never told what to
  // store, or is shown the daemon's token instead of words.
  test('both refusals are read as what they say, on a call and on a watch', () async {
    daemon.fails('PullRequests', 'org.fuin.porelo.Tasks1.MissingHostForgeToken', <String, dynamic>{
      'credential': 'forge.person',
      'storeCommand': <Object>['porelo', 'host', 'forge-token'],
    });
    daemon.fails('WatchPullRequests', 'org.fuin.porelo.Tasks1.HostPullRequestsRefused', <String, dynamic>{
      'reason': 'vault-unreadable',
      'message': 'the vault is locked or unreadable; unlock or repair it before reading reviews',
    });
    final client = await connect();

    final missing = await client.pullRequests('foo').then<Object>((_) => 'answered', onError: (Object e) => e);
    expect(missing, isA<MissingHostForgeToken>());
    expect((missing as MissingHostForgeToken).credential, 'forge.person');
    expect(missing.storeCommand, <String>['porelo', 'host', 'forge-token']);

    final refused = await client
        .watchPullRequests('foo')
        .first
        .then<Object>((_) => 'answered', onError: (Object e) => e);
    expect(refused, isA<HostPullRequestsRefused>());
    expect((refused as HostPullRequestsRefused).reason, 'vault-unreadable');
    expect(refused.message, contains('unlock or repair it'));
  });

  // Harm: a machine older than the calls reads as one with no pull requests, or takes the window down.
  test('a machine without the calls says so for them alone', () async {
    final client = await connect();
    expect(client.pullRequests('foo'), throwsA(isA<FeatureNotSupported>()));
    expect(client.watchPullRequests('foo').first, throwsA(isA<FeatureNotSupported>()));
  });
}

Future<void> _until(bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
