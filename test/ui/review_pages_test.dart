import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/app/gate.dart';
import 'package:porelo_frontend/src/ui/gate_view.dart';

/// A review whose diff, or whose file list, is not read whole, as the person meets it.
void main() {
  final project = Project.from(const <String, dynamic>{'name': 'checkout', 'file': '/srv/p.yml'});
  const longPath = 'services/payments/src/main/java/org/example/payments/rounding/HalfEvenRoundingPolicy.java';
  const patchA = 'diff --git a/a.dart b/a.dart\n--- a/a.dart\n+++ b/a.dart\n@@ -1 +1 @@\n-x\n+y\n';
  const headOfB = 'diff --git a/$longPath b/$longPath\n--- a/$longPath\n+++ b/$longPath\n@@ -1,2 +1,2 @@\n-p\n';

  Future<Gate> looking(PushReview review, {ReviewPage? page, _OneReview? on}) async {
    final backend = on ?? _OneReview(review, page);
    final gate = Gate();
    await gate.lookAt(backend, project);
    await gate.look(backend, gate.waiting.single);
    return gate;
  }

  Future<void> show(WidgetTester tester, Gate gate, {double width = 1280, VoidCallback? onReadMore}) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReviewView(
            gate: gate,
            onBack: () {},
            onClose: () {},
            onApprove: () {},
            onReject: () {},
            onReadMoreDiff: onReadMore,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  PushReview partly() => PushReview(
    commit: '9a3c1f2e4b5d6a7c8e9f0a1b2c3d4e5f6a7b8c9d',
    files: <ReviewFile>[_file('a.dart'), _file(longPath), _file('c.dart')],
    diff: '$patchA$headOfB',
    paged: ReviewPaged(
      files: 3,
      commits: 0,
      logBytes: 0,
      diffBytes: 4096,
      base: '',
      diffNext: patchA.length + headOfB.length,
    ),
  );

  // Harm: a person forwards a push believing they saw all of it, while files' patches were never read.
  for (final width in <double>[1280, 390]) {
    testWidgets('at $width wide, a diff not read whole says how much is read and which patches are not', (
      tester,
    ) async {
      final gate = await looking(partly());
      var asked = 0;
      await show(tester, gate, width: width, onReadMore: () => asked++);

      final list = find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first;
      Future<void> seen(Finder finder) async {
        await tester.scrollUntilVisible(finder, 100, scrollable: list);
        expect(finder, findsOneWidget);
      }

      expect(tester.takeException(), isNull);
      await seen(find.byKey(const ValueKey<String>('review-file a.dart')));
      expect(find.byKey(const ValueKey<String>('review-patch inPart a.dart')), findsNothing);
      expect(find.byKey(const ValueKey<String>('review-patch notReadYet a.dart')), findsNothing);
      await seen(find.text(longPath));
      await seen(find.byKey(const ValueKey<String>('review-patch inPart $longPath')));
      await seen(find.byKey(const ValueKey<String>('review-patch notReadYet c.dart')));
      await seen(find.byKey(const Key('review-diff-read-words')));
      expect(tester.takeException(), isNull);
      final words = tester.widget<Text>(find.byKey(const Key('review-diff-read-words'))).data!;
      expect(words, contains('of 4 KiB of the diff read'));
      expect(find.text('Copy the diff read so far'), findsOneWidget);
      expect(find.text('Copy the diff'), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(const Key('review-forward-partly-read'))).data,
        contains('Forwarding sends all of it, read or not.'),
      );
      expect(tester.widget<FilledButton>(find.byKey(const Key('review-forward'))).onPressed, isNotNull);

      await tester.ensureVisible(find.byKey(const Key('review-read-more')));
      await tester.tap(find.byKey(const Key('review-read-more')));
      expect(asked, 1);
    });
  }

  // Harm: a part of the file list is drawn as the whole list, and forwarded from.
  testWidgets('a file list not read whole shows no file and does not offer the forward, saying why', (tester) async {
    final gate = await looking(
      PushReview(
        commit: '9a3c1f2e4b5d6a7c8e9f0a1b2c3d4e5f6a7b8c9d',
        files: <ReviewFile>[_file('a.dart')],
        diff: patchA,
        paged: const ReviewPaged(files: 2, commits: 0, logBytes: 0, diffBytes: 0, base: '', filesNext: 1),
      ),
      // A page that does not move on: the machine's fault, and the list stays unread.
      page: (files: <ReviewFile>[_file('b.dart')], commits: null, text: null, next: 1),
    );
    await show(tester, gate);

    expect(find.byKey(const ValueKey<String>('review-file a.dart')), findsNothing);
    expect(find.byKey(const Key('review-not-whole')), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('review-forward'))).onPressed, isNull);
    expect(tester.widget<Text>(find.byKey(const Key('review-forward-refused'))).data, contains(Gate.notWholeWords));
  });

  // Harm: a file whose patch the machine cut from its answer reads as a file without a change.
  testWidgets('a file the machine left out of a cut diff is said to be left out, with the command for all of it', (
    tester,
  ) async {
    const command = <String>['porelo', 'gate', 'review', 'migrate'];
    final gate = await looking(
      PushReview(
        commit: '9a3c1f2e4b5d6a7c8e9f0a1b2c3d4e5f6a7b8c9d',
        files: <ReviewFile>[_file('a.dart'), _file('c.dart')],
        diff: patchA,
        cut: const ReviewCut(shownFiles: 1, omittedFiles: 1, omitted: <String>['c.dart'], command: command),
      ),
    );
    await show(tester, gate);

    expect(find.byKey(const ValueKey<String>('review-patch leftOut c.dart')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('review-patch leftOut a.dart')), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const Key('review-diff-read-words'))).data,
      contains('patches of 1 of 2 files'),
    );
    expect(find.text(command.join(' ')), findsOneWidget);
    expect(find.text('Copy the diff read so far'), findsOneWidget);
  });

  // Harm: a second click while a page is read asks another, and a forward goes out while its review may yet move.
  testWidgets('while a part of the diff is read, its button and the forward are offered to nobody, saying why', (
    tester,
  ) async {
    final backend = _OneReview(partly(), null)..held = Completer<ReviewPage>();
    final gate = await looking(partly(), on: backend);
    final reading = gate.readMoreDiff(backend);
    await show(tester, gate, onReadMore: () {});

    final list = find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.byKey(const Key('review-read-more')), 100, scrollable: list);
    expect(tester.widget<OutlinedButton>(find.byKey(const Key('review-read-more'))).onPressed, isNull);
    expect(find.text('The next part is being read.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('review-forward'))).onPressed, isNull);
    expect(
      tester.widget<Text>(find.byKey(const Key('review-forward-refused'))).data,
      'The next part of the diff is being read.',
    );

    backend.held!.complete((files: null, commits: null, text: 'x\n', next: 9000));
    await reading;
  });

  // Harm: the branch is chosen in a dialog that does not say the diff was read only in part.
  testWidgets('the branch dialog says how much of the diff was read', (tester) async {
    final gate = await looking(partly());
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => askWhichBranch(context, subject: 'Round', partlyRead: gate.diffReadWords),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
      tester.widget<Text>(find.byKey(const Key('forward-partly-read'))).data,
      allOf(contains('of 4 KiB of the diff read'), contains('Forwarding sends all of it, read or not.')),
    );
  });
}

ReviewFile _file(String path) =>
    ReviewFile(path: path, status: 'M', added: 1, removed: 1, rank: 'ORDINARY', reason: '');

/// One push waits, its review answers [review], and every page answers [page].
class _OneReview implements FleetBackend {
  _OneReview(this.review, this.page);

  final PushReview review;
  final ReviewPage? page;

  /// Where set, every page waits for it.
  Completer<ReviewPage>? held;

  @override
  Future<GateState> gateOf(String projectFile, {String? repository}) async => GateState.from(const <String, dynamic>{
    'mode': 'gatekeeping',
    'pending': <Map<String, dynamic>>[
      <String, dynamic>{'name': 'migrate', 'commit': '9a3c1f2', 'subject': 'Round', 'waiting': '1 minute'},
    ],
  });

  @override
  Future<String> contract() async => '';

  @override
  Future<PushReview> reviewOf(
    String projectFile,
    String name, {
    String? against,
    String? repository,
    bool? ignoreLineEndings,
  }) async => review;

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
  }) => held?.future ?? Future<ReviewPage>.value(page ?? (throw StateError('no page was expected')));

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
