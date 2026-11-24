import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/app/gate.dart';

import 'fleet_model_test.dart' show aBackendThatRefusesEverything;

/// The gate refuses to be asked about a project it cannot name.
///
/// Unreachable from the interface, which offers no gate for such a project and says why — but a
/// caller could still get here, and opening on nothing would be the wrong answer.
void main() {
  test('a project with no file is not asked about at all', () async {
    final gate = Gate();

    await gate.lookAt(
      aBackendThatRefusesEverything,
      Project.from(const <String, dynamic>{'name': 'unrecorded', 'file': ''}),
    );

    expect(gate.reachable, isFalse);
    expect(gate.problem, contains('is not on this machine'));
    expect(gate.waiting, isEmpty);
  });

  test('a push forwarded is said to be, even when another repository could not be read', () async {
    final backend = _OneOfTwoGatesReadable();
    final gate = Gate();

    await gate.lookAt(
      backend,
      Project.from(const <String, dynamic>{
        'name': 'checkout',
        'file': '/srv/checkout/project.yml',
        'repositories': <String>['checkout', 'payments-api'],
      }),
    );
    expect(gate.problem, contains('payments-api could not be read'));
    expect(gate.waiting.single.repository, 'checkout');

    await gate.look(backend, gate.waiting.single);
    final answer = await gate.approve(backend, 'fix-rounding');

    expect(answer.forwarded, isTrue);
    expect(answer.said, contains('was forwarded to fix-rounding'));
    expect(backend.approvedIn, <String?>['checkout']);
  });

  // The harm: the caller's proposed branch is reported as the actual destination.
  test('a forward names only the destination confirmed by the answer', () async {
    final backend = _OneOfTwoGatesReadable()..forwardedBranch = 'porelo/migrate';
    final gate = Gate();
    await gate.lookAt(backend, Project.from(const <String, dynamic>{'name': 'checkout', 'file': '/srv/p.yml'}));
    await gate.look(backend, gate.waiting.single);
    final answer = await gate.approve(backend, '');
    expect(answer.forwarded, isTrue);
    expect(answer.said, contains('was forwarded to porelo/migrate'));
    expect(
      answer.said,
      isNot(contains('refs/porelo/forwarded/')),
      reason: 'Approve returns the incoming name, with no retained ref or commit',
    );
  });

  // The harm: the window said the diff left line ends out while the machine had sent it whole.
  test('the diff is said to leave line ends out only when it was asked without them', () async {
    final backend = _ContractReadOnce();
    final gate = Gate();
    await gate.lookAt(backend, Project.from(const <String, dynamic>{'name': 'checkout', 'file': '/srv/p.yml'}));
    await gate.look(backend, gate.waiting.single);
    expect(gate.servesWithoutLineEndings, isTrue);

    await gate.showWithoutLineEndings(backend, true);
    expect(backend.asked.last, isNull, reason: 'the contract could not be read this time, so nothing was sent');
    expect(gate.withoutLineEndings, isFalse, reason: 'the diff shown holds the line ends');
  });

  // Harm: a summary read before the gate was read again answers last and shows counts of a read no longer shown.
  test("an older read of the waiting pushes' summaries never overwrites a newer one", () async {
    final backend = _HeldSummaries();
    final gate = Gate();
    final project = Project.from(const <String, dynamic>{'name': 'checkout', 'file': '/srv/p.yml'});
    await gate.lookAt(backend, project);
    final push = gate.waiting.single;
    expect(gate.checksOf(push)?.reading, isTrue, reason: 'read, and said to be read meanwhile');
    await gate.lookAt(backend, project);
    backend.held[1].complete(_summary(threads: 2));
    await pumpEventQueue();
    backend.held[0].complete(_summary(threads: 9));
    await pumpEventQueue();
    expect(gate.checksOf(gate.waiting.single)?.summary?.openThreads, 2);
  });

  // Harm: an older machine's missing summary, or a refusal, reads as zero findings and threads.
  test('a summary not answered is said as not reported or refused, never as zeros', () async {
    final backend = _HeldSummaries();
    final gate = Gate();
    await gate.lookAt(backend, Project.from(const <String, dynamic>{'name': 'checkout', 'file': '/srv/p.yml'}));
    backend.held.single.completeError(const FeatureNotSupported('ReviewSummary'));
    await pumpEventQueue();
    final checks = gate.checksOf(gate.waiting.single)!;
    expect(checks.summary, isNull);
    expect(checks.words, 'Checks: not reported');
  });

  // Harm: an answer that fails in a way nobody named leaves its row, and every row read beside it, reading forever.
  test('a summary that fails in an unforeseen way is said, and the other rows are read', () async {
    final backend = _HeldSummaries()..pending = 2;
    final gate = Gate();
    await gate.lookAt(backend, Project.from(const <String, dynamic>{'name': 'checkout', 'file': '/srv/p.yml'}));
    backend.held[0].completeError(StateError('the connection was closed'));
    backend.held[1].complete(_summary(threads: 1));
    await pumpEventQueue();
    final [first, second] = gate.waiting;
    expect(gate.checksOf(first)?.reading, isFalse);
    expect(gate.checksOf(first)?.words, contains('the connection was closed'));
    expect(gate.checksOf(second)?.summary?.openThreads, 1);
  });

  // Harm: every refresh of the list blanks counts already read into "reading", and they flicker on every read.
  test('a row read before keeps its counts until its new answer, and a new commit starts as reading', () async {
    final backend = _HeldSummaries();
    final gate = Gate();
    final project = Project.from(const <String, dynamic>{'name': 'checkout', 'file': '/srv/p.yml'});
    await gate.lookAt(backend, project);
    backend.held.single.complete(_summary(threads: 2));
    await pumpEventQueue();
    await gate.lookAt(backend, project);
    expect(gate.checksOf(gate.waiting.single)?.summary?.openThreads, 2, reason: 'kept while asked again');
    backend.held[1].complete(_summary(threads: 3));
    await pumpEventQueue();
    expect(gate.checksOf(gate.waiting.single)?.summary?.openThreads, 3);
    backend.commit = '7f21b0e';
    await gate.lookAt(backend, project);
    expect(gate.checksOf(gate.waiting.single)?.reading, isTrue, reason: 'another commit has no counts yet');
  });

  group('a review read in pages', () {
    final project = Project.from(const <String, dynamic>{'name': 'checkout', 'file': '/srv/p.yml'});

    Future<Gate> looking(_Pages backend) async {
      final gate = Gate();
      await gate.lookAt(backend, project);
      await gate.look(backend, gate.waiting.single);
      return gate;
    }

    // Harm: a file list shown while only its first page is read is taken for every file the push changes.
    test('files and commits are joined page by page, in order, before anything of them is drawn', () async {
      final backend =
          _Pages(<PushReview>[
              PushReview(
                commit: _first,
                files: <ReviewFile>[_file('a')],
                commits: <ReviewCommit>[_commit(_first)],
                paged: const ReviewPaged(
                  files: 3,
                  commits: 2,
                  logBytes: 0,
                  diffBytes: 0,
                  base: '',
                  filesNext: 1,
                  commitsNext: 1,
                ),
              ),
            ])
            ..onPage = (part, from) async => switch ((part, from)) {
              ('files', 1) => (files: <ReviewFile>[_file('b')], commits: null, text: null, next: 2),
              ('files', 2) => (files: <ReviewFile>[_file('c')], commits: null, text: null, next: null),
              ('commits', 1) => (files: null, commits: <ReviewCommit>[_commit(_second)], text: null, next: null),
              _ => throw StateError('$part $from was never given'),
            };
      final gate = Gate();
      await gate.lookAt(backend, project);
      final seen = <int>[];
      gate.addListener(() => seen.add(gate.ranked.length));

      await gate.look(backend, gate.waiting.single);

      expect([for (final file in gate.ranked) file.path], <String>['a', 'b', 'c']);
      expect([for (final commit in gate.commits!) commit.commit], <String>[_first, _second]);
      expect(seen.where((count) => count != 0 && count != 3), isEmpty, reason: 'never a part of the list');
      expect(gate.listsWhole, isTrue);
      expect(gate.forwardRefused, isNull);
    });

    // Harm: a page whose next does not move on is asked forever, and what was joined is shown as the list.
    test(
      'a page that does not move on stops the reading, is said as the machine’s fault, and nothing more is asked',
      () async {
        final backend = _Pages(<PushReview>[
          PushReview(
            commit: _first,
            files: <ReviewFile>[_file('a')],
            paged: const ReviewPaged(files: 3, commits: 0, logBytes: 0, diffBytes: 0, base: '', filesNext: 1),
          ),
        ])..onPage = (part, from) async => (files: <ReviewFile>[_file('b')], commits: null, text: null, next: 1);

        final gate = await looking(backend);

        expect(backend.pages, hasLength(1));
        expect(gate.listsWhole, isFalse);
        expect(gate.ranked, isEmpty);
        expect(gate.problem, contains('never should'));
        expect(gate.forwardRefused, contains(Gate.notWholeWords));
        expect((await gate.approve(backend, 'main')).forwarded, isFalse);
        expect(backend.approved, isEmpty);
      },
    );

    // Harm: the diff's pages are not one stream, so a file whose header starts a page is lost or doubled, and the
    // file before it is taken for whole.
    test('a diff page that starts on a file header is put after what is read, as one stream', () async {
      final backend = _Pages(<PushReview>[
        PushReview(
          commit: _first,
          files: <ReviewFile>[_file('a.dart'), _file('b.dart')],
          diff: _patchA,
          paged: ReviewPaged(
            files: 2,
            commits: 0,
            logBytes: 0,
            diffBytes: _patchA.length + _patchB.length,
            base: _base,
            diffNext: _patchA.length,
          ),
        ),
      ])..onPage = (part, from) async => (files: null, commits: null, text: _patchB, next: null);
      final gate = await looking(backend);

      expect([for (final file in gate.changed) file.path], <String>['a.dart']);
      expect(gate.diffContinues, isTrue, reason: 'the last file read may go on in the next page');
      expect(gate.diffReadWords, contains('of the diff read'));

      await gate.readMoreDiff(backend);

      expect(backend.pages.single, (
        part: 'diff',
        from: _patchA.length,
        commit: _first,
        against: _base,
        ignoreLineEndings: false,
      ));
      expect(gate.diff, '$_patchA$_patchB');
      expect([for (final file in gate.changed) file.path], <String>['a.dart', 'b.dart']);
      expect(gate.diffWhole, isTrue);
      expect(gate.diffReadWords, isNull);
    });

    // Harm: the next page of a push that moved is of another commit, and the review shown mixes the two.
    test('a push that moved is read again from the top once, said, and its next page waits for a click', () async {
      final backend = _Pages(<PushReview>[_withMore(_first), _withMore(_second)]);
      backend.onPage = (part, from) async {
        if (backend.pages.length == 1) {
          backend.pending = _pushAt(_second);
          throw const VarlinkException('org.fuin.porelo.Tasks1.MovedSinceReview', <String, dynamic>{
            'name': 'migrate',
            'reviewed': _first,
            'now': _second,
          });
        }
        return (files: null, commits: null, text: _patchB, next: null);
      };
      final gate = await looking(backend);

      await gate.readMoreDiff(backend);

      expect(backend.reviews, 2);
      expect(backend.pages, hasLength(1), reason: 'the next page of the push read again waits for the person');
      expect(gate.reviewed, _second);
      expect(gate.diff, _patchA);
      expect(gate.diffNext, _patchA.length);
      expect(gate.problem, contains('moved since it was read'));
      await gate.approve(backend, 'main');
      expect(backend.approved, <String?>[_second]);
    });

    // Harm: a push that keeps moving under the review is read again and again without end.
    test('a list page that says the push moved again after it was read again is said, not read a third time', () async {
      final backend = _Pages(<PushReview>[
        PushReview(
          commit: _first,
          files: <ReviewFile>[_file('a')],
          paged: const ReviewPaged(files: 2, commits: 0, logBytes: 0, diffBytes: 0, base: '', filesNext: 1),
        ),
      ])..onPage = (part, from) async => throw const VarlinkException('org.fuin.porelo.Tasks1.MovedSinceReview');

      final gate = await looking(backend);

      expect(backend.reviews, 2);
      expect(backend.pages, hasLength(2));
      expect(gate.listsWhole, isFalse);
      expect(gate.problem, contains('moved since it was read'));
    });

    // Harm: a position the machine refused is asked again and again, or the refusal hides the forward.
    test('a refused page is said and not asked again, and the push can still be forwarded', () async {
      final backend = _Pages(<PushReview>[_withMore(_first)])
        ..onPage = (part, from) async => throw const VarlinkException(
          'org.varlink.service.InvalidParameter',
          <String, dynamic>{'parameter': 'from'},
        );
      final gate = await looking(backend);

      await gate.readMoreDiff(backend);
      await gate.readMoreDiff(backend);

      expect(backend.pages, hasLength(1));
      expect(gate.diffNext, isNull);
      expect(gate.diffStopped, contains('naming from'));
      expect(gate.problem, contains('The rest of the diff was not read'));
      expect(gate.diffWhole, isFalse);
      expect(gate.forwardRefused, isNull);
    });

    // Harm: a lost connection reads as the end of the diff, and its rest is never offered again.
    test('a page lost with the connection can be asked again', () async {
      final backend = _Pages(<PushReview>[_withMore(_first)]);
      backend.onPage = (part, from) async {
        if (backend.pages.length == 1) throw const VarlinkDisconnected('gone for a moment');
        return (files: null, commits: null, text: _patchB, next: null);
      };
      final gate = await looking(backend);

      await gate.readMoreDiff(backend);
      expect(gate.diffNext, _patchA.length);
      expect(gate.problem, contains('Lost contact'));
      await gate.readMoreDiff(backend);

      expect(backend.pages, hasLength(2));
      expect(gate.diff, '$_patchA$_patchB');
    });

    // Harm: a page that answers after another push, or the other line-end choice, is opened lands in that review.
    test('a page answered after the review was read again is dropped', () async {
      final late = Completer<ReviewPage>();
      final backend = _Pages(<PushReview>[_withMore(_first)])..onPage = (part, from) => late.future;
      final gate = await looking(backend);

      final reading = gate.readMoreDiff(backend);
      await gate.look(backend, gate.waiting.single);
      late.complete((files: null, commits: null, text: _patchB, next: null));
      await reading;

      expect(gate.diff, _patchA);
      expect(gate.diffNext, _patchA.length);
      expect(gate.readingDiff, isFalse);
    });

    // Harm: the commit the waiting list named before the review was read is forwarded, though the review shown is
    // of another, or a review that names no commit is forwarded unchecked.
    test('forwarding sends the commit the review is of, and a review naming none is not forwarded', () async {
      final backend = _Pages(<PushReview>[const PushReview(commit: _second), const PushReview()]);
      final gate = await looking(backend);

      await gate.approve(backend, 'main');
      expect(backend.approved, <String?>[_second]);

      backend.pending = _pushAt(_first);
      await gate.lookAt(backend, project);
      await gate.look(backend, gate.waiting.single);
      final answer = await gate.approve(backend, 'main');

      expect(answer.forwarded, isFalse);
      expect(answer.said, contains('did not name the commit'));
      expect(backend.approved, hasLength(1));
    });

    // Harm: a page asked against another base, or with the other line-end choice, than the review shown is a
    // page of another diff, joined to this one as if it were its rest.
    test('every page carries the base the review was read against and the line-end choice it was read with', () async {
      final backend = _Pages(<PushReview>[_withMore(_first)])
        ..onPage = (part, from) async => (files: null, commits: null, text: _patchB, next: null);
      final gate = await looking(backend);
      await gate.showWithoutLineEndings(backend, true);
      expect(gate.withoutLineEndings, isTrue);

      await gate.readMoreDiff(backend);

      expect(backend.pages.single, (
        part: 'diff',
        from: _patchA.length,
        commit: _first,
        against: _base,
        ignoreLineEndings: true,
      ));
    });

    // Harm: while a moved push is read again, the old review stays live, and a second click asks a page of the
    // commit that no longer waits.
    test('a second click while a moved push is read again asks no page, and nothing is forwarded meanwhile', () async {
      final backend = _Pages(<PushReview>[_withMore(_first), _withMore(_second)]);
      backend.onPage = (part, from) async {
        backend.pending = _pushAt(_second);
        backend.holdTheGate = Completer<void>();
        throw const VarlinkException('org.fuin.porelo.Tasks1.MovedSinceReview', <String, dynamic>{
          'name': 'migrate',
          'reviewed': _first,
          'now': _second,
        });
      };
      final gate = await looking(backend);

      final first = gate.readMoreDiff(backend);
      await backend.gateAsked.future;
      expect(gate.reviewHeld, isFalse);
      expect(gate.busy, isTrue);
      expect(gate.forwardRefused, isNotNull);
      await gate.readMoreDiff(backend);
      expect((await gate.approve(backend, 'main')).forwarded, isFalse);
      backend.holdTheGate!.complete();
      await first;

      expect(backend.pages, hasLength(1));
      expect(backend.approved, isEmpty);
      expect(gate.reviewed, _second);
      expect(gate.busy, isFalse);
    });

    // Harm: the diff's size is counted in characters rather than UTF-8 bytes, and a diff with "ü" or an emoji is
    // refused as the machine's fault, or a short one taken for whole.
    test('a diff with letters of several bytes is counted in UTF-8 bytes and joined', () async {
      final whole = utf8.encode(_patchU).length + utf8.encode(_patchEmoji).length;
      final backend = _Pages(<PushReview>[_withBytes(whole)])
        ..onPage = (part, from) async => (files: null, commits: null, text: _patchEmoji, next: null);
      final gate = await looking(backend);
      expect(gate.diffRead, utf8.encode(_patchU).length);

      await gate.readMoreDiff(backend);

      expect(gate.diffStopped, isNull);
      expect(gate.diffWhole, isTrue);
      expect(gate.diffRead, whole);
      expect(gate.diff, '$_patchU$_patchEmoji');
    });

    // Harm: a diff that ends short of the size the machine counted is taken for whole.
    test('a diff that ends short of the bytes the machine counted is said, not taken for whole', () async {
      final whole = utf8.encode(_patchU).length + utf8.encode(_patchEmoji).length + 1;
      final backend = _Pages(<PushReview>[_withBytes(whole)])
        ..onPage = (part, from) async => (files: null, commits: null, text: _patchEmoji, next: null);
      final gate = await looking(backend);

      await gate.readMoreDiff(backend);

      expect(gate.diffStopped, contains('never should'));
      expect(gate.diffWhole, isFalse);
      expect(gate.diff, _patchU);
    });

    // Harm: a forward decided while the next part is read goes out on a review the page may yet show to have moved.
    test('the push is not forwarded while a part of its diff is being read', () async {
      final page = Completer<ReviewPage>();
      final backend = _Pages(<PushReview>[_withMore(_first)])..onPage = (part, from) => page.future;
      final gate = await looking(backend);

      final reading = gate.readMoreDiff(backend);
      expect(gate.forwardRefused, 'The next part of the diff is being read.');
      expect((await gate.approve(backend, 'main')).forwarded, isFalse);
      page.complete((files: null, commits: null, text: _patchB, next: null));
      await reading;

      expect(backend.approved, isEmpty);
      expect(gate.forwardRefused, isNull);
    });
  });
}

const _patchU = 'diff --git a/ü.dart b/ü.dart\n--- a/ü.dart\n+++ b/ü.dart\n@@ -1 +1 @@\n-ü\n+üü\n';
const _patchEmoji = 'diff --git a/e.dart b/e.dart\n--- a/e.dart\n+++ b/e.dart\n@@ -1 +1 @@\n-x\n+😀\n';

/// A review whose diff holds the patch of ü.dart, and the next page that of e.dart, of [whole] bytes in all.
PushReview _withBytes(int whole) => PushReview(
  commit: _first,
  files: <ReviewFile>[_file('ü.dart'), _file('e.dart')],
  diff: _patchU,
  paged: ReviewPaged(
    files: 2,
    commits: 0,
    logBytes: 0,
    diffBytes: whole,
    base: _base,
    diffNext: utf8.encode(_patchU).length,
  ),
);

const _first = '9a3c1f2e4b5d6a7c8e9f0a1b2c3d4e5f6a7b8c9d';
const _second = '1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c';
const _base = '0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d';
const _patchA = 'diff --git a/a.dart b/a.dart\n--- a/a.dart\n+++ b/a.dart\n@@ -1 +1 @@\n-x\n+y\n';
const _patchB = 'diff --git a/b.dart b/b.dart\n--- a/b.dart\n+++ b/b.dart\n@@ -1 +1 @@\n-p\n+q\n';

ReviewFile _file(String path) =>
    ReviewFile(path: path, status: 'M', added: 1, removed: 1, rank: 'ORDINARY', reason: '');

ReviewCommit _commit(String commit) => ReviewCommit(commit: commit, subject: 'Round', trailers: const <String>[]);

/// A review of two files whose diff holds the first file's patch, the second's on the next page.
PushReview _withMore(String commit) => PushReview(
  commit: commit,
  files: <ReviewFile>[_file('a.dart'), _file('b.dart')],
  diff: _patchA,
  paged: ReviewPaged(
    files: 2,
    commits: 0,
    logBytes: 0,
    diffBytes: _patchA.length + _patchB.length,
    base: _base,
    diffNext: _patchA.length,
  ),
);

List<Map<String, dynamic>> _pushAt(String commit) => <Map<String, dynamic>>[
  <String, dynamic>{'name': 'migrate', 'commit': commit, 'subject': 'Round', 'waiting': '1 minute'},
];

/// A gate whose Review answers [answers] in turn, the last again, and whose pages answer [onPage].
class _Pages implements FleetBackend {
  _Pages(this.answers);

  final List<PushReview> answers;
  var reviews = 0;
  List<Map<String, dynamic>> pending = _pushAt(_first);
  Future<ReviewPage> Function(String part, int from) onPage = (part, from) async =>
      throw StateError('no page was expected');
  final pages = <({String part, int from, String commit, String against, bool ignoreLineEndings})>[];
  final approved = <String?>[];

  /// Held until completed, where set: the gate's list is being read again.
  Completer<void>? holdTheGate;

  /// Completed when the gate's list is asked while [holdTheGate] holds it.
  final gateAsked = Completer<void>();

  @override
  Future<GateState> gateOf(String projectFile, {String? repository}) async {
    final hold = holdTheGate;
    if (hold != null) {
      if (!gateAsked.isCompleted) gateAsked.complete();
      await hold.future;
    }
    return GateState.from(<String, dynamic>{'mode': 'gatekeeping', 'pending': pending});
  }

  @override
  Future<String> contract() async => 'method Review(project: string, name: string, ignoreLineEndings: ?bool) -> ()';

  @override
  Future<PushReview> reviewOf(
    String projectFile,
    String name, {
    String? against,
    String? repository,
    bool? ignoreLineEndings,
  }) async => answers[reviews++ < answers.length ? reviews - 1 : answers.length - 1];

  @override
  Future<ReviewPage> reviewPageOf(
    String projectFile,
    String name, {
    String? repository,
    required String commit,
    required String against,
    required bool ignoreLineEndings,
    required String part,
    required int from,
  }) {
    pages.add((part: part, from: from, commit: commit, against: against, ignoreLineEndings: ignoreLineEndings));
    return onPage(part, from);
  }

  @override
  Future<ForwardedPush> approve(
    String projectFile,
    String name,
    String branch, {
    String? repository,
    String? commit,
  }) async {
    approved.add(commit);
    return ForwardedPush.from(<String, dynamic>{'forwarded': name, 'branch': branch});
  }

  /// Older than the review summary, as this stand-in is: what it tests reads no checks.
  @override
  Future<ReviewSummary> reviewSummaryOf(
    String projectFile,
    String name, {
    String? repository,
    required String commit,
  }) => Future<ReviewSummary>.error(const FeatureNotSupported('ReviewSummary'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Serves the line-end switch, and then cannot say what it serves.
class _ContractReadOnce extends _OneOfTwoGatesReadable {
  final asked = <bool?>[];
  var reads = 0;

  @override
  Future<String> contract() async {
    if (reads++ > 0) throw const VarlinkDisconnected('gone for a moment');
    return 'method Review(project: string, name: string, ignoreLineEndings: ?bool) -> ()';
  }

  @override
  Future<PushReview> reviewOf(
    String projectFile,
    String name, {
    String? against,
    String? repository,
    bool? ignoreLineEndings,
  }) async {
    asked.add(ignoreLineEndings);
    return const PushReview(commit: '9a3c1f2');
  }
}

/// The project's own repository answers; the other's mirror is gone.
class _OneOfTwoGatesReadable implements FleetBackend {
  final approvedIn = <String?>[];
  String? forwardedBranch;

  @override
  Future<GateState> gateOf(String projectFile, {String? repository}) async {
    if (repository == 'payments-api') {
      throw const VarlinkException('org.fuin.porelo.Tasks1.Failed', <String, dynamic>{
        'message': 'the mirror is missing',
      });
    }
    return GateState.from(const <String, dynamic>{
      'mode': 'gatekeeping',
      'pending': <Map<String, dynamic>>[
        <String, dynamic>{'name': 'migrate', 'commit': '9a3c1f2', 'subject': 'Round', 'waiting': '1 minute'},
      ],
    });
  }

  @override
  Future<PushReview> reviewOf(
    String projectFile,
    String name, {
    String? against,
    String? repository,
    bool? ignoreLineEndings,
  }) async => const PushReview(commit: '9a3c1f2');

  @override
  Future<ForwardedPush> approve(
    String projectFile,
    String name,
    String branch, {
    String? repository,
    String? commit,
  }) async {
    approvedIn.add(repository);
    return ForwardedPush.from(<String, dynamic>{'forwarded': name, 'branch': forwardedBranch ?? branch});
  }

  /// Older than the review summary, as this stand-in is: what it tests reads no checks.
  @override
  Future<ReviewSummary> reviewSummaryOf(
    String projectFile,
    String name, {
    String? repository,
    required String commit,
  }) => Future<ReviewSummary>.error(const FeatureNotSupported('ReviewSummary'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ReviewSummary _summary({required int threads}) => ReviewSummary(
  openFindings: 0,
  openThreads: threads,
  runs: const <ReviewRun>[ReviewRun(name: 'owner review', completeness: 'complete', findings: 0)],
);

/// One push waiting, whose summaries answer only when a test completes them, in the order asked.
class _HeldSummaries implements FleetBackend {
  final held = <Completer<ReviewSummary>>[];

  /// How many pushes wait, each its own name.
  int pending = 1;

  /// The commit the first waits at.
  String commit = '9a3c1f2';

  @override
  Future<GateState> gateOf(String projectFile, {String? repository}) async => GateState.from(<String, dynamic>{
    'mode': 'gatekeeping',
    'pending': <Map<String, dynamic>>[
      for (var each = 0; each < pending; each++)
        <String, dynamic>{
          'name': each == 0 ? 'migrate' : 'migrate-$each',
          'commit': each == 0 ? commit : '1b2c3d$each',
          'subject': 'Round',
          'waiting': '1 minute',
        },
    ],
  });

  @override
  Future<ReviewSummary> reviewSummaryOf(String projectFile, String name, {String? repository, required String commit}) {
    final answer = Completer<ReviewSummary>();
    held.add(answer);
    return answer.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
