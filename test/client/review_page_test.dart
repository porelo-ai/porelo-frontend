// Linux only: it stands the mock daemon on a unix socket, and on GitHub's Windows runner a test
// through it hung where no timeout could end it.
@Tags(<String>['linux'])
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/mock/machine.dart';
import 'package:porelo_frontend/src/mock/mock_daemon.dart';

/// A large review read in pages: `Review.paged` and `ReviewPage`, over a real socket.
void main() {
  late MockDaemon daemon;

  setUp(() async {
    daemon = MockDaemon();
    await daemon.start();
  });

  tearDown(() => daemon.stop());

  Future<PoreloClient> connect() => PoreloClient.connect(Backend(socketPath: daemon.socketPath, label: 'mock'));

  const commit = '9a3c1f2e4b5d6a7c8e9f0a1b2c3d4e5f6a7b8c9d';
  const base = '1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c';

  Map<String, dynamic> pagedReview({Map<String, dynamic> paged = const <String, dynamic>{}}) => <String, dynamic>{
    'commit': commit,
    'diff': 'diff --git a/a b/a\n',
    'log': '',
    'files': <Map<String, dynamic>>[
      <String, dynamic>{'path': 'a', 'status': 'M', 'added': 1, 'removed': 0, 'rank': 'ORDINARY', 'reason': ''},
    ],
    'commits': <Map<String, dynamic>>[],
    'paged': <String, dynamic>{
      'files': 1,
      'commits': 0,
      'logBytes': 0,
      'diffBytes': 40,
      'diffNext': 19,
      'base': base,
      ...paged,
    },
  };

  // Harm: a page asked with a default the daemon resolves again, or without the commit, could be of
  // another commit or base than the review shown, and the window would join two reviews into one.
  test('a page is asked with exactly the review commit, its base, the line-end choice, part and position', () async {
    final asked = <Map<String, dynamic>>[];
    daemon.method('Review', (_) => pagedReview());
    daemon.method('ReviewPage', (parameters) {
      asked.add(parameters);
      return <String, dynamic>{'text': 'more of it\n'};
    });
    final client = await connect();

    final review = await client.review('checkout', 'migrate', repository: 'payments-api');
    final paged = review.paged!;
    final page = await client.reviewPage(
      'checkout',
      'migrate',
      repository: 'payments-api',
      commit: review.commit!,
      against: paged.base,
      ignoreLineEndings: false,
      part: 'diff',
      from: paged.diffNext!,
    );

    expect(asked.single, <String, dynamic>{
      'project': 'checkout',
      'repository': 'payments-api',
      'name': 'migrate',
      'commit': commit,
      'against': base,
      'ignoreLineEndings': false,
      'part': 'diff',
      'from': 19,
    });
    expect(page.text, 'more of it\n');
    expect(page.next, isNull);
  });

  // Harm: a position the machine did not mean is sent back, or a part read as whole while it is not.
  test('a paged that does not fit what the review holds is refused, never taken', () async {
    final client = await connect();
    final wrong = <String, Map<String, dynamic>>{
      'a next past its size': <String, dynamic>{'diffNext': 40},
      'no next for a part not whole': <String, dynamic>{'diffNext': null},
      'a next for a part held whole': <String, dynamic>{'filesNext': 0},
      'a size that is no whole number': <String, dynamic>{'files': '1'},
      'a negative next': <String, dynamic>{'diffNext': -1},
      'no base': <String, dynamic>{'base': null},
      'more held than counted': <String, dynamic>{'files': 0},
    };
    for (final MapEntry(key: what, value: paged) in wrong.entries) {
      daemon.method('Review', (_) => pagedReview(paged: paged));
      await expectLater(client.review('checkout', 'migrate'), throwsA(isA<FormatException>()), reason: what);
    }
  });

  // Harm: a page without its part reads as an empty page, or an end, and a list is shown short.
  test('a page without the part asked, or with a next that is no position, is refused', () async {
    final client = await connect();
    Future<ReviewPage> ask(String part) => client.reviewPage(
      'checkout',
      'migrate',
      commit: commit,
      against: '',
      ignoreLineEndings: false,
      part: part,
      from: 1,
    );

    daemon.method('ReviewPage', (_) => <String, dynamic>{'text': 'x\n'});
    await expectLater(ask('files'), throwsA(isA<FormatException>()));
    await expectLater(ask('commits'), throwsA(isA<FormatException>()));
    daemon.method('ReviewPage', (_) => <String, dynamic>{'files': <Object>[]});
    await expectLater(ask('diff'), throwsA(isA<FormatException>()));
    daemon.method('ReviewPage', (_) => <String, dynamic>{'text': 'x\n', 'next': '5'});
    await expectLater(ask('diff'), throwsA(isA<FormatException>()));
  });

  // Harm: a machine without ReviewPage would be read as one whose review has no more to it.
  test('a machine without ReviewPage says so, never an empty page', () async {
    final client = await connect();

    await expectLater(
      client.reviewPage(
        'checkout',
        'migrate',
        commit: commit,
        against: '',
        ignoreLineEndings: false,
        part: 'diff',
        from: 1,
      ),
      throwsA(isA<FeatureNotSupported>()),
    );
  });

  // Harm: the stand-in a person opens the window against pages differently from the daemon, so paging is
  // seen to work there and not on a machine.
  test('the mock machine pages its review, and the pages join into the whole', () async {
    final machine = MockMachine(daemon, pace: Duration.zero);
    addTearDown(machine.close);
    final client = await connect();
    final whole = await client.review('checkout', 'migrate');

    machine.reviewPageSize = 1;
    final first = await client.review('checkout', 'migrate');
    final paged = first.paged!;
    var diff = first.diff;
    var from = paged.diffNext;
    while (from != null) {
      final page = await client.reviewPage(
        'checkout',
        'migrate',
        commit: first.commit!,
        against: paged.base,
        ignoreLineEndings: false,
        part: 'diff',
        from: from,
      );
      diff += page.text!;
      from = page.next;
    }
    final files = <ReviewFile>[...first.files];
    from = paged.filesNext;
    while (from != null) {
      final page = await client.reviewPage(
        'checkout',
        'migrate',
        commit: first.commit!,
        against: paged.base,
        ignoreLineEndings: false,
        part: 'files',
        from: from,
      );
      files.addAll(page.files!);
      from = page.next;
    }

    expect(diff, whole.diff);
    expect(utf8.encode(diff).length, paged.diffBytes);
    expect([for (final file in files) file.path], [for (final file in whole.files) file.path]);
    await expectLater(
      client.reviewPage(
        'checkout',
        'migrate',
        commit: 'another',
        against: '',
        ignoreLineEndings: false,
        part: 'diff',
        from: paged.diffNext!,
      ),
      throwsA(isA<VarlinkException>().having((refusal) => refusal.simpleName, 'simpleName', 'MovedSinceReview')),
    );
    await expectLater(
      client.reviewPage(
        'checkout',
        'migrate',
        commit: first.commit!,
        against: '',
        ignoreLineEndings: false,
        part: 'diff',
        from: paged.diffNext! + 1,
      ),
      throwsA(isA<VarlinkException>().having((refusal) => refusal.simpleName, 'simpleName', 'InvalidParameter')),
    );
  });
}
