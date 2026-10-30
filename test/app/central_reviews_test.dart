import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/central_reviews.dart';
import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/app/forge.dart';
import 'package:porelo_frontend/src/app/forge_connection.dart';

const _forge = ForgeEntry(id: 'central', kind: 'github', name: 'Central', address: 'example.org');

class _Source implements CentralForgeSource {
  final client = _Reviews();
  final accounts = <(ForgeEntry, String)>[];
  bool denied = false;
  Object? failure;
  @override
  Future<T> withReviews<T>(ForgeEntry forge, String person, Future<T> Function(CentralForgeReviews) use) async {
    accounts.add((forge, person));
    if (failure case final error?) throw error;
    if (denied) throw const ForgeRefused('permission denied');
    return use(client);
  }
}

class _Reviews implements CentralForgeReviews {
  final requests = <CentralPullRequest>[];
  final reviewed = <int, List<CentralReview>>{};
  final calls = <String>[];
  bool lost = false;
  Object? failure;
  Completer<void>? wait;
  @override
  Future<CentralPullRequest> create(
    String repository, {
    required String title,
    required String body,
    required String head,
    required String base,
  }) async {
    calls.add('create $repository');
    await wait?.future;
    final request = CentralPullRequest(
      number: requests.length + 1,
      title: title,
      body: body,
      head: head,
      base: base,
      state: 'open',
    );
    requests.add(request);
    if (failure case final error?) throw error;
    if (lost) throw const CentralResponseLost();
    return request;
  }

  @override
  Future<CentralPage<CentralPullRequest>> list(String repository, {String? page}) async {
    calls.add('list $repository ${page ?? "first"}');
    if (failure case final error?) throw error;
    return page == null
        ? CentralPage(requests.take(1).toList(), next: requests.length > 1 ? 'more' : null)
        : CentralPage(requests.skip(1).toList());
  }

  @override
  Future<CentralPullRequest> read(String repository, int number) async {
    calls.add('read $repository $number');
    return requests.singleWhere((request) => request.number == number);
  }

  @override
  Future<CentralPage<CentralReview>> reviews(String repository, int number, {String? page}) async {
    calls.add('reviews $repository $number');
    return CentralPage(reviewed[number] ?? []);
  }

  @override
  Future<CentralReview> submit(String repository, int number, CentralReviewDecision decision, String body) async {
    calls.add('submit $repository $number');
    final review = CentralReview(
      id: (reviewed[number]?.length ?? 0) + 1,
      author: 'alice',
      body: body,
      state: decision.name,
    );
    reviewed.putIfAbsent(number, () => []).add(review);
    if (failure case final error?) throw error;
    if (lost) throw const CentralResponseLost();
    return review;
  }
}

void main() {
  late _Source source;
  late CentralReviews actions;
  setUp(() {
    source = _Source();
    actions = CentralReviews(source: source, forge: _forge, person: 'alice', repository: 'org/api');
  });
  tearDown(() => actions.dispose());
  Future<CentralPullRequest> create() => actions.create(title: 'A change', body: 'Details', head: 'work', base: 'main');

  // Harm: viewing a project can make a central request without the person's intent.
  test('construction does no work and explicit actions use the captured person and repository', () async {
    expect(source.accounts, isEmpty);
    final first = await create();
    await create();
    final page = await actions.list();
    expect(page.items.map((request) => request.number), [1]);
    expect(page.next, 'more');
    expect((await actions.list(page: page.next)).items.map((request) => request.number), [2]);
    expect(await actions.read(first.number), same(first));
    final review = await actions.submit(first.number, CentralReviewDecision.approve, 'Read and checked');
    expect((await actions.reviews(first.number)).items, [review]);
    expect(review.author, 'alice');
    expect(review.state, 'approve');
    expect(source.accounts, List.filled(7, (_forge, 'alice')));
    expect(source.client.calls, [
      'create org/api',
      'create org/api',
      'list org/api first',
      'list org/api more',
      'read org/api 1',
      'submit org/api 1',
      'reviews org/api 1',
    ]);
  });

  // Harm: a denied or missing vault credential is treated as authorization to write.
  test('denied authentication never reaches a forge write', () async {
    source.denied = true;
    await expectLater(create(), throwsA(isA<ForgeRefused>()));
    await expectLater(actions.list(), throwsA(isA<ForgeRefused>()));
    await expectLater(actions.submit(1, CentralReviewDecision.comment, 'text'), throwsA(isA<ForgeRefused>()));
    expect(source.client.calls, isEmpty);
  });

  // Harm: a lost create reply causes a duplicate pull request on replay.
  test('lost creation needs explicit reconciliation and is never retried automatically', () async {
    source.client.lost = true;
    await expectLater(create(), throwsA(isA<CentralResponseLost>()));
    await expectLater(create(), throwsA(isA<ForgeRefused>()));
    expect(source.client.requests.length, 1);
    await expectLater(
      actions.reconcile(() async {
        throw Exception('unreadable');
      }),
      throwsException,
    );
    expect(actions.unavailable, isNotNull);
    await actions.reconcile(() async {
      expect((await actions.list()).items.length, 1);
    });
    expect(actions.unavailable, isNull);
  });

  // Harm: a lost review response causes a duplicate review.
  test('a lost review reply blocks a second review until observed state is read', () async {
    await create();
    source.client.lost = true;
    await expectLater(
      actions.submit(1, CentralReviewDecision.requestChanges, 'Please adjust'),
      throwsA(isA<CentralResponseLost>()),
    );
    await expectLater(
      actions.submit(1, CentralReviewDecision.requestChanges, 'Please adjust'),
      throwsA(isA<ForgeRefused>()),
    );
    expect(source.client.reviewed[1]!.length, 1);
    await actions.reconcile(() async {
      expect((await actions.reviews(1)).items.length, 1);
    });
    expect(actions.unavailable, isNull);
  });

  // Harm: a decoder Error after a successful write allows duplicate requests or reviews.
  test('errors after create and review remain sanitized and block replay', () async {
    for (final review in [false, true]) {
      if (review) {
        source = _Source();
        actions = CentralReviews(source: source, forge: _forge, person: 'alice', repository: 'org/api');
        await create();
      }
      source.client.failure = StateError('private decoder diagnostic');
      final pending = review ? actions.submit(1, CentralReviewDecision.approve, '') : create();
      await expectLater(pending, throwsA(isA<CentralResponseLost>()));
      await expectLater(create(), throwsA(isA<ForgeRefused>()));
      expect(review ? source.client.reviewed[1]!.length : source.client.requests.length, 1);
    }
  });

  // Harm: reconciliation permits replay while the timed out forge write can still complete.
  testWidgets('a timed out central write stays pending until its original request settles', (tester) async {
    actions = CentralReviews(
      source: source,
      forge: _forge,
      person: 'alice',
      repository: 'org/api',
      answerWithin: const Duration(seconds: 1),
    );
    source.client.wait = Completer<void>();
    final pending = create();
    final failed = expectLater(pending, throwsA(isA<CentralResponseLost>()));
    await tester.pump(const Duration(seconds: 1));
    await failed;
    await expectLater(
      actions.reconcile(() async {
        await actions.list();
      }),
      throwsA(isA<ForgeRefused>()),
    );
    await expectLater(create(), throwsA(isA<ForgeRefused>()));
    source.client.wait!.complete();
    await tester.pump();
    expect(source.client.requests.length, 1);
    await actions.reconcile(() async {
      expect((await actions.list()).items.length, 1);
    });
    expect(actions.unavailable, isNull);
  });

  // Harm: a command captured before a write can open another write flow while it is blocked.
  test('captured central write commands check current availability at dispatch', () async {
    var creates = 0;
    var submits = 0;
    final commands = centralReviewCommands(
      project: 'example',
      list: () {},
      create: () {
        creates++;
      },
      submit: () {
        submits++;
      },
      actions: actions,
    );
    source.client.wait = Completer<void>();
    final pending = create();
    expect(commands.singleWhere((c) => c.id == 'centralPullRequest.create').run, throwsA(isA<ForgeRefused>()));
    expect(commands.singleWhere((c) => c.id == 'centralPullRequest.review').run, throwsA(isA<ForgeRefused>()));
    expect([creates, submits], [0, 0]);
    source.client.wait!.complete();
    await pending;
  });

  // Harm: a stored command misrepresents a running or uncertain write as available.
  test('stored commands expose the current refusal instead of silently ignoring dispatch', () async {
    final commands = centralReviewCommands(
      project: 'example',
      list: () {},
      create: () {},
      submit: () {},
      actions: actions,
    );
    final writes = commands.where((c) => c.id == 'centralPullRequest.create' || c.id == 'centralPullRequest.review');
    source.client.wait = Completer<void>();
    final pending = create();
    expect(writes.every((c) => c.unavailable == actions.unavailable), isTrue);
    for (final command in writes) {
      expect(command.run, throwsA(isA<ForgeRefused>()));
    }
    source.client.wait!.complete();
    await pending;
    source.client.lost = true;
    await expectLater(create(), throwsA(isA<CentralResponseLost>()));
    expect(writes.every((c) => c.unavailable == actions.unavailable), isTrue);
  });

  // Harm: a previous project can still send writes or reads after its controller is disposed.
  test('disposed reviews refuse stored commands and direct actions before authentication', () async {
    var opens = 0;
    final commands = centralReviewCommands(
      project: 'example',
      list: () {
        opens++;
      },
      create: () {
        opens++;
      },
      read: () {
        opens++;
      },
      reviews: () {
        opens++;
      },
      submit: () {
        opens++;
      },
      actions: actions,
    );
    actions.dispose();
    for (final command in commands) {
      expect(command.unavailable, isNotNull);
      expect(command.run, throwsA(isA<ForgeRefused>()));
    }
    await expectLater(create(), throwsA(isA<ForgeRefused>()));
    await expectLater(actions.list(), throwsA(isA<ForgeRefused>()));
    expect(opens, 0);
    expect(source.accounts, isEmpty);
    actions = CentralReviews(source: source, forge: _forge, person: 'alice', repository: 'org/api');
  });

  // Harm: programming errors in authentication and reads are disguised as permission refusals.
  test('pre-submission errors propagate without becoming authentication refusals', () async {
    final failure = StateError('decoder failure');
    source.failure = failure;
    await expectLater(create(), throwsA(same(failure)));
    expect(actions.unavailable, isNull);
  });

  // Harm: a decoding Error on a read hides a programming defect as lost authentication.
  test('read errors propagate without becoming authentication refusals', () async {
    final failure = StateError('decoder failure');
    source.client.failure = failure;
    await expectLater(actions.list(), throwsA(same(failure)));
  });

  // Harm: a menu keeps stale write availability after settlement or reconciliation.
  test('central write transitions notify menus including late settlement', () async {
    final availability = <String?>[];
    actions.addListener(() => availability.add(actions.unavailable));
    source.client.wait = Completer<void>();
    final pending = create();
    expect(availability, isNotEmpty);
    expect(availability.last, isNotNull);
    source.client.wait!.complete();
    await pending;
    expect(availability.last, isNull);
    source.client.lost = true;
    await expectLater(create(), throwsA(isA<CentralResponseLost>()));
    expect(availability.last, contains('unconfirmed'));
    await actions.reconcile(() async {
      await actions.list();
    });
    expect(availability.last, isNull);
  });

  // Harm: double clicking starts concurrent writes.
  test('a pending write refuses a duplicate', () async {
    source.client.wait = Completer<void>();
    final pending = create();
    await expectLater(create(), throwsA(isA<ForgeRefused>()));
    source.client.wait!.complete();
    await pending;
    expect(source.client.requests.length, 1);
  });
}
