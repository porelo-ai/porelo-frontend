// Linux only: it stands the mock daemon on a unix socket, and on GitHub's Windows runner a test
// through it hung where no timeout could end it.
@Tags(<String>['linux'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/mock/mock_daemon.dart';

/// Who made a waiting push and its trailer, as `Pending` and `Review` report them.
void main() {
  late MockDaemon daemon;

  setUp(() async {
    daemon = MockDaemon();
    await daemon.start();
  });

  tearDown(() => daemon.stop());

  Future<PoreloClient> connect() => PoreloClient.connect(Backend(socketPath: daemon.socketPath, label: 'mock'));

  // The harm: what an older machine does not report reads as no trailer at all, which a check
  // could then judge.
  test('a machine older than the makers leaves them absent, never empty', () async {
    daemon.method('Review', (_) => <String, dynamic>{'diff': '', 'log': ''});
    final push = PendingPush.from(const <String, dynamic>{'name': 'migrate', 'commit': 'abc'});

    final review = await (await connect()).review('checkout', 'migrate');

    expect(review.commits, isNull);
    expect((push.author, push.committer, push.trailers), (null, null, null));
  });

  test('the makers of each commit are read field by field, an unknown field passed over', () async {
    daemon.method(
      'Review',
      (_) => <String, dynamic>{
        'diff': '',
        'log': '',
        'commits': <Map<String, dynamic>>[
          <String, dynamic>{
            'commit': '9a3c1f2e4b5d6a7c8e9f0a1b2c3d4e5f6a7b8c9d',
            'subject': 'Round to the nearest penny',
            'author': 'An Agent <agent@example.org>',
            'committer': 'A Person <person@example.org>',
            'trailers': <String>['Assisted-by: Claude Code, claude-opus-5-5'],
            'message': 'a field this build does not know',
          },
        ],
      },
    );

    final commit = (await (await connect()).review('checkout', 'migrate')).commits!.single;

    expect(commit.commit, '9a3c1f2e4b5d6a7c8e9f0a1b2c3d4e5f6a7b8c9d');
    expect(commit.author, 'An Agent <agent@example.org>');
    expect(commit.committer, 'A Person <person@example.org>');
    expect(commit.trailers, <String>['Assisted-by: Claude Code, claude-opus-5-5']);
  });

  // The harm: a parser that drops what it cannot read leaves a shorter list, and the Co-Authored-By
  // it dropped is then checked as absent.
  test('a trailer list with a line that is no text is unread as a whole, and nothing throws', () {
    final push = PendingPush.from(const <String, dynamic>{
      'name': 'migrate',
      'author': 7,
      'trailers': <Object?>['Assisted-by: Claude Code, claude-opus-5-5', null],
    });
    final commit = ReviewCommit.from(const <String, dynamic>{
      'commit': 'abc',
      'trailers': <Object?>['Assisted-by: Claude Code, claude-opus-5-5', 42],
    });

    expect((push.author, push.trailers), (null, null));
    expect((commit.author, commit.trailers), (null, null));
    expect(
      ReviewCommit.allIn(<Object?>[
        <String, dynamic>{'commit': 'abc'},
        'no commit',
      ]),
      isNull,
    );
    expect(ReviewCommit.allIn('no list'), isNull);
  });

  // The harm: the makers are lost when a push is placed in its repository, and read as unreported.
  test('the makers stay with a push placed in its repository', () {
    final push = PendingPush.from(const <String, dynamic>{
      'name': 'migrate',
      'author': 'An Agent <agent@example.org>',
      'committer': 'A Person <person@example.org>',
      'trailers': <String>['Assisted-by: Claude Code, claude-opus-5-5'],
    }).inRepository('payments-api');

    expect(push.author, 'An Agent <agent@example.org>');
    expect(push.committer, 'A Person <person@example.org>');
    expect(push.trailers, <String>['Assisted-by: Claude Code, claude-opus-5-5']);
  });

  // The harm: a message the machine could not match to its commit reads as one with no co-author,
  // and the check passes on it.
  test('an empty message is no message, for a waiting push and for each commit', () {
    final push = PendingPush.from(const <String, dynamic>{'name': 'migrate', 'commit': 'abc', 'message': ''});
    final commit = ReviewCommit.from(const <String, dynamic>{'commit': 'abc', 'subject': 's', 'message': ''});
    final whole = ReviewCommit.from(const <String, dynamic>{'commit': 'abc', 'subject': 's', 'message': 's\n'});

    expect((push.message, commit.message), (null, null));
    expect(whole.message, 's\n');
  });
}
