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

  // Harm: trailer lines with anything but text in them read as a list the trailer check can judge, so a commit with
  // makers unreported shows none.
  test('trailers holding anything but text are not reported', () {
    expect(
      HostPullRequest.from(<String, dynamic>{
        'trailers': <Object>[123],
      }).trailers,
      isNull,
    );
    expect(
      HostPullRequest.from(<String, dynamic>{
        'trailers': <Object?>['Assisted-by: a, b', null],
      }).trailers,
      isNull,
    );
  });

  // Harm: a faulty machine's store command carries what breaks out of a terminal's paste, or is copied cut short.
  test('a store command with a word that is no text, is empty, or holds a control or line separator is none', () {
    for (final words in <List<Object?>>[
      <Object?>['porelo', 'host', 7],
      <Object?>['porelo', ''],
      <Object?>['porelo', '\x1b[201~'],
      <Object?>['porelo', 'a\nb'],
      <Object?>['porelo', 'a\u2028b'],
      <Object?>['porelo', 'a\x85b'],
    ]) {
      final missing = MissingHostForgeToken(
        VarlinkException('org.fuin.porelo.Tasks1.MissingHostForgeToken', <String, dynamic>{'storeCommand': words}),
      );
      expect(missing.storeCommand, isEmpty, reason: '$words');
    }
  });

  // Harm: one repository's refusal is lost, so its pull requests vanish unexplained, or it silences the others' rows;
  // an answer from an older machine, without the field, reads as a refusal.
  test('a repository refused alone is read with its status and path, beside the others still answered', () async {
    daemon.method(
      'PullRequests',
      (_) => <String, dynamic>{
        'pullRequests': <Map<String, dynamic>>[row(1)],
        'ended': <Object>[],
        'refused': <Object?>[
          <String, dynamic>{
            'repository': 'foo-2',
            'reason': 'forge-access',
            'status': 404,
            'path': '/api/v1/repos/foo/foo-2/pulls',
            'message': 'the host forge answers 404',
          },
          <String, dynamic>{'repository': 'foo-3', 'reason': 'a-later-reason', 'status': 'five', 'path': ''},
          <String, dynamic>{'reason': 'forge', 'status': 500},
          'not a refusal',
        ],
      },
    );

    final seen = await (await connect()).pullRequests('foo');

    expect(seen.open.single.repository, 'foo-1');
    expect(seen.refused, hasLength(2));
    final access = seen.refused.first;
    expect(access.repository, 'foo-2');
    expect(access.reason, 'forge-access');
    expect(access.status, 404);
    expect(access.path, '/api/v1/repos/foo/foo-2/pulls');
    expect(access.message, 'the host forge answers 404');
    final later = seen.refused.last;
    expect(later.reason, 'a-later-reason');
    expect(later.status, isNull);
    expect(later.path, isNull);
    expect(later.message, isEmpty);

    final older = PullRequestsSeen.from(<String, dynamic>{
      'pullRequests': <Map<String, dynamic>>[row(1)],
      'ended': <Object>[],
    });
    expect(older.refused, isEmpty);
    expect(older.open.single.number, 1);
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

  const reading = '0123456789abcdef0123456789abcdef';
  Map<String, dynamic> paged(int open, int ended, int next) => <String, dynamic>{
    'reading': reading,
    'pullRequests': open,
    'ended': ended,
    'next': next,
  };

  // A reading of three open and one ended pull request: its first row in the reply, the rest in two pages.
  Map<String, dynamic> firstOfFour() => <String, dynamic>{
    'pullRequests': <Map<String, dynamic>>[row(1)],
    'ended': <Object>[],
    'paged': paged(3, 1, 1),
  };
  Map<String, dynamic> pageOfFour(int from) => switch (from) {
    1 => <String, dynamic>{
      'pullRequests': <Map<String, dynamic>>[row(2)],
      'ended': <Object>[],
      'next': 2,
    },
    _ => <String, dynamic>{
      'pullRequests': <Map<String, dynamic>>[row(3)],
      'ended': <Map<String, dynamic>>[row(4, state: 'merged')],
    },
  };

  // Harm: a pull request waiting for the person is never shown because the machine's list did not fit one message,
  // or a page is asked for with a position the machine did not give.
  test('a list in pages is read whole, each page asked where the last one ended, on a call and on a watch', () async {
    final asked = <Map<String, dynamic>>[];
    daemon.method('PullRequestsPage', (parameters) {
      asked.add(parameters);
      return pageOfFour(parameters['from'] as int);
    });
    daemon.method('PullRequests', (_) => firstOfFour());
    final changes = StreamController<Map<String, dynamic>>();
    addTearDown(changes.close);
    daemon.pushes('WatchPullRequests', (_) => changes.stream);
    final client = await connect();

    final seen = await client.pullRequests('foo');
    expect(seen.open.map((each) => each.number), <int>[1, 2, 3]);
    expect(seen.ended.map((each) => each.number), <int>[4]);
    expect(asked, <Map<String, dynamic>>[
      <String, dynamic>{'project': 'foo', 'reading': reading, 'from': 1},
      <String, dynamic>{'project': 'foo', 'reading': reading, 'from': 2},
    ]);

    final watched = <PullRequestsSeen>[];
    final watching = client.watchPullRequests('foo').listen(watched.add);
    addTearDown(watching.cancel);
    changes.add(firstOfFour());
    await _until(() => watched.isNotEmpty);
    expect(watched.single.open.map((each) => each.number), <int>[1, 2, 3]);
    expect(watched.single.ended.map((each) => each.number), <int>[4]);
  });

  // Harm: a list that keeps changing while it is read in pages never reaches the window, so an old one stays shown as
  // current; or a snapshot overtaken meanwhile is shown after the newer one.
  test('a watch reads one snapshot to its end, then only the newest of those that came meanwhile', () async {
    final held = Completer<void>();
    daemon.method('PullRequestsPage', (parameters) async {
      if (parameters['from'] == 1) await held.future;
      return pageOfFour(parameters['from'] as int);
    });
    final changes = StreamController<Map<String, dynamic>>();
    addTearDown(changes.close);
    daemon.pushes('WatchPullRequests', (_) => changes.stream);
    final watched = <PullRequestsSeen>[];
    final watching = (await connect()).watchPullRequests('foo').listen(watched.add);
    addTearDown(watching.cancel);

    changes.add(firstOfFour());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    for (final number in <int>[7, 8]) {
      changes.add(<String, dynamic>{
        'pullRequests': <Map<String, dynamic>>[row(number)],
        'ended': <Object>[],
      });
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
    held.complete();
    await _until(() => watched.length == 2);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(watched.map((each) => each.open.map((row) => row.number).toList()), <List<int>>[
      <int>[1, 2, 3],
      <int>[8],
    ]);
  });

  // Harm: a pull request confirmed ended by a snapshot skipped for a newer one is kept as open, asking for a merge
  // that was made.
  test('the ends a skipped snapshot confirmed go with the next one given', () async {
    final held = Completer<void>();
    daemon.method('PullRequestsPage', (parameters) async {
      if (parameters['from'] == 1) await held.future;
      return pageOfFour(parameters['from'] as int);
    });
    final changes = StreamController<Map<String, dynamic>>();
    addTearDown(changes.close);
    daemon.pushes('WatchPullRequests', (_) => changes.stream);
    final watched = <PullRequestsSeen>[];
    final watching = (await connect()).watchPullRequests('foo').listen(watched.add);
    addTearDown(watching.cancel);

    changes.add(firstOfFour());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    changes.add(<String, dynamic>{
      'pullRequests': <Map<String, dynamic>>[row(2)],
      'ended': <Map<String, dynamic>>[row(3, state: 'merged')],
    });
    changes.add(<String, dynamic>{
      'pullRequests': <Map<String, dynamic>>[row(2)],
      'ended': <Object>[],
    });
    await Future<void>.delayed(const Duration(milliseconds: 50));
    held.complete();
    await _until(() => watched.length == 2);

    expect(watched.last.open.map((each) => each.number), <int>[2]);
    expect(watched.last.ended.map((each) => (each.number, each.state)), <(int, String)>[(3, 'merged')]);
  });

  // Harm: a watch the window let go of goes on asking the machine for pages, or gives a list after it was cancelled.
  test('a watch cancelled while a page is read asks for no further page and gives nothing', () async {
    final held = Completer<void>();
    final asked = <int>[];
    daemon.method('PullRequestsPage', (parameters) async {
      asked.add(parameters['from'] as int);
      await held.future;
      return pageOfFour(parameters['from'] as int);
    });
    final changes = StreamController<Map<String, dynamic>>();
    addTearDown(changes.close);
    daemon.pushes('WatchPullRequests', (_) => changes.stream);
    final watched = <PullRequestsSeen>[];
    final watching = (await connect()).watchPullRequests('foo').listen(watched.add);

    changes.add(firstOfFour());
    await _until(() => asked.isNotEmpty);
    await watching.cancel();
    held.complete();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(asked, <int>[1]);
    expect(watched, isEmpty);
  });

  // Harm: a reading the machine let go of leaves an old list shown as current, or overtakes a newer one waiting.
  test('a reading let go of goes over to a newer snapshot waiting, and with none ends the watch', () async {
    final held = Completer<void>();
    var pages = 0;
    daemon.method('PullRequestsPage', (parameters) async {
      if (pages++ == 0) await held.future;
      throw const MockRefusal('org.fuin.porelo.Tasks1.PullRequestsReadingGone', <String, dynamic>{
        'project': 'foo',
        'reading': reading,
      });
    });
    final changes = StreamController<Map<String, dynamic>>();
    addTearDown(changes.close);
    daemon.pushes('WatchPullRequests', (_) => changes.stream);
    final watched = <PullRequestsSeen>[];
    Object? ended;
    final watching = (await connect()).watchPullRequests('foo').listen(watched.add, onError: (Object e) => ended = e);
    addTearDown(watching.cancel);

    changes.add(firstOfFour());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    changes.add(<String, dynamic>{
      'pullRequests': <Map<String, dynamic>>[row(9)],
      'ended': <Object>[],
    });
    await Future<void>.delayed(const Duration(milliseconds: 50));
    held.complete();
    await _until(() => watched.isNotEmpty);
    expect(watched.single.open.single.number, 9);
    expect(ended, isNull);

    changes.add(firstOfFour());
    await _until(() => ended != null);
    expect(ended, isA<VarlinkException>().having((e) => e.simpleName, 'name', 'PullRequestsReadingGone'));
    expect(watched, hasLength(1), reason: 'no partial list is given');
  });

  // Harm: pages that do not fit together are shown as the whole list, or asked for without end.
  final breaches = <String, ({Map<String, dynamic> first, Map<String, dynamic>? page})>{
    'a page held no row': (
      first: firstOfFour(),
      page: <String, dynamic>{'pullRequests': <Object>[], 'ended': <Object>[], 'next': 1},
    ),
    'it named row 1 as next after 2 rows': (
      first: firstOfFour(),
      page: <String, dynamic>{
        'pullRequests': <Map<String, dynamic>>[row(2)],
        'ended': <Object>[],
        'next': 1,
      },
    ),
    'it gave more rows than it counted': (
      first: firstOfFour(),
      page: <String, dynamic>{
        'pullRequests': <Map<String, dynamic>>[row(2), row(3), row(5)],
        'ended': <Object>[],
        'next': 4,
      },
    ),
    'it gave ended pull requests before every open one': (
      first: firstOfFour(),
      page: <String, dynamic>{
        'pullRequests': <Object>[],
        'ended': <Map<String, dynamic>>[row(4, state: 'merged')],
        'next': 2,
      },
    ),
    'its pages ended with 2 open and 0 ended of 3 and 1': (
      first: firstOfFour(),
      page: <String, dynamic>{
        'pullRequests': <Map<String, dynamic>>[row(2)],
        'ended': <Object>[],
      },
    ),
    'its pages gave a pull request twice': (
      first: firstOfFour(),
      page: <String, dynamic>{
        'pullRequests': <Map<String, dynamic>>[row(1), row(3)],
        'ended': <Map<String, dynamic>>[row(4, state: 'merged')],
      },
    ),
    'it named a next page after all 1 rows': (
      first: <String, dynamic>{
        'pullRequests': <Map<String, dynamic>>[row(1)],
        'ended': <Object>[],
        'paged': paged(1, 0, 1),
      },
      page: null,
    ),
    'more than the 100000 read at most': (
      first: <String, dynamic>{
        'pullRequests': <Map<String, dynamic>>[row(1)],
        'ended': <Object>[],
        'paged': paged(100000, 1, 1),
      },
      page: null,
    ),
    'it named pages but gives none': (first: firstOfFour(), page: null),
  };
  for (final MapEntry(key: what, value: (:first, :page)) in breaches.entries) {
    test('pages where $what end the watch, said as such', () async {
      if (page != null) daemon.method('PullRequestsPage', (_) => page);
      final changes = StreamController<Map<String, dynamic>>();
      addTearDown(changes.close);
      daemon.pushes('WatchPullRequests', (_) => changes.stream);
      final watched = <PullRequestsSeen>[];
      Object? ended;
      final watching = (await connect()).watchPullRequests('foo').listen(watched.add, onError: (Object e) => ended = e);
      addTearDown(watching.cancel);

      changes.add(first);
      await _until(() => ended != null);

      expect(ended, isA<PullRequestsPagingBroken>().having((e) => e.what, 'what', contains(what)));
      expect(watched, isEmpty);
    });
  }

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
