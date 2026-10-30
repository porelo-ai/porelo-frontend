import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/central_reviews.dart';
import 'package:porelo_frontend/src/app/forge.dart';
import 'package:porelo_frontend/src/app/forge_connection.dart';

const _forge = ForgeEntry(id: 'central', kind: 'github', name: 'Central', address: 'example.org');

class _Source implements CentralForgeSource {
  final client = _Reviews();
  final accounts = <(ForgeEntry, String)>[];
  bool denied = false;
  @override
  Future<T> withReviews<T>(ForgeEntry forge, String person, Future<T> Function(CentralForgeReviews) use) async {
    accounts.add((forge, person));
    if (denied) throw const ForgeRefused('permission denied');
    return use(client);
  }
}

class _Reviews implements CentralForgeReviews {
  final requests = <CentralPullRequest>[];
  final reviewed = <int, List<CentralReview>>{};
  final calls = <String>[];
  bool lost = false;
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
    if (lost) throw const CentralResponseLost();
    return request;
  }

  @override
  Future<CentralPage<CentralPullRequest>> list(String repository, {String? page}) async {
    calls.add('list $repository ${page ?? "first"}');
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
