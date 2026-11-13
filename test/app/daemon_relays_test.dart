import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/loopback_carrier.dart';

/// A card's daemon relays on Windows: each is an ssh child of the window that uses the person's key, so they wait for
/// places of their own and count under the cap of all beside the carried connections.
void main() {
  const call = RelayUse.call();
  const stream = RelayUse.stream();

  /// Asks for a place and keeps what comes of it: the place once given, null once abandoned.
  ({List<RelayPlace?> got, Future<RelayPlace?> asked}) ask(
    DaemonRelays relays,
    RelayUse use, {
    Future<void>? abandoned,
  }) {
    final got = <RelayPlace?>[];
    final asked = relays.enter(use, abandoned: abandoned)..then(got.add);
    return (got: got, asked: asked);
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('a burst of calls past the pool waits and each is admitted in turn, none refused', () async {
    final relays = CarrierBudget(daemonCalls: 2).daemonOf('box');
    final asks = [for (var i = 0; i < 6; i++) ask(relays, call)];
    await settle();
    final admitted = <int>[];
    void seen() {
      for (var i = 0; i < asks.length; i++) {
        if (asks[i].got.isNotEmpty && !admitted.contains(i)) admitted.add(i);
      }
    }

    seen();
    expect(admitted, [0, 1], reason: 'two places, so the first two of the burst are admitted and the rest wait');
    while (admitted.length < asks.length) {
      final held = admitted.where((i) => asks[i].got.single != null).toList();
      asks[held.first].got.single!.leave();
      asks[held.first].got[0] = null;
      await settle();
      final before = admitted.length;
      seen();
      expect(admitted.length, before + 1, reason: 'each place given back admits exactly the next one waiting');
    }
    expect(admitted, [0, 1, 2, 3, 4, 5], reason: 'the calls are admitted in the order they asked');
  });

  test('each watch holds a place of its own that calls never take, and the same watch again waits for it', () async {
    final relays = CarrierBudget(daemonCalls: 2).daemonOf('box');
    final calls = [for (var i = 0; i < 4; i++) ask(relays, call)];
    final watches = [for (final method in PoreloClient.watches) ask(relays, RelayUse.watch(method))];
    await settle();
    expect([for (final each in watches) each.got.length], [1, 1, 1, 1], reason: 'every watch runs beside a full pool');
    expect([for (final each in calls) each.got.length], [1, 1, 0, 0], reason: 'the calls wait for the pool alone');

    final again = ask(relays, const RelayUse.watch('Watch'));
    await settle();
    expect(again.got, isEmpty, reason: 'a watch already running holds its place, so the same watch waits');
    watches.first.got.single!.leave();
    await settle();
    expect(again.got, hasLength(1), reason: 'the watch is admitted once its place was given back');
    expect([for (final each in calls) each.got.length], [1, 1, 0, 0], reason: 'a watch place never goes to a call');
  });

  test('streams never hold the last place of the pool, so a call still passes', () async {
    final relays = CarrierBudget(daemonCalls: 3).daemonOf('box');
    final streams = [for (var i = 0; i < 4; i++) ask(relays, stream)];
    await settle();
    expect([for (final each in streams) each.got.length], [1, 1, 0, 0], reason: 'streams take all but one place');
    final asked = ask(relays, call);
    await settle();
    expect(asked.got, hasLength(1), reason: 'the last place is a call’s, ahead of the waiting streams');
  });

  test('the cap of all counts the daemon calls beside the carried connections', () async {
    final budget = CarrierBudget(inAll: 3);
    final relays = budget.daemonOf('box');
    final first = [ask(relays, call), ask(relays, stream)];
    await settle();
    expect([for (final each in first) each.got.length], [1, 1]);
    expect(budget.take(), isTrue, reason: 'one place of the three is left for a carried connection');
    expect(budget.take(), isFalse, reason: 'the call, the stream and the connection hold every place');
    final asked = ask(relays, call);
    await settle();
    expect(asked.got, isEmpty, reason: 'a call waits while every place of all is held');
    budget.giveBack();
    await settle();
    expect(asked.got, hasLength(1), reason: 'the place a connection gave back goes to the waiting call');
    expect(budget.take(), isFalse, reason: 'and not to a new connection');
  });

  test('every card’s watches and follows come up at once, past the cap of all, and take none of its places', () async {
    final budget = CarrierBudget(inAll: 4);
    final cards = [for (var i = 0; i < 5; i++) budget.daemonOf('card$i')];
    final held = [
      for (final card in cards) ...[
        for (final method in PoreloClient.watches) ask(card, RelayUse.watch(method)),
        ask(card, const RelayUse.follow()),
        ask(card, const RelayUse.follow()),
      ],
    ];
    await settle();
    expect(
      [for (final each in held) each.got.length],
      everyElement(1),
      reason: 'five cards hold 30 watches and follows, and none of them waits',
    );
    final calls = [for (final card in cards) ask(card, call)];
    await settle();
    expect(
      [for (final each in calls) each.got.length],
      [1, 1, 1, 1, 0],
      reason: 'calls still wait for the cap of all, which the watches left whole',
    );
    expect(budget.take(), isFalse, reason: 'the four calls hold every place of all');
  });

  test('streams that end never hold the last place of all', () async {
    final budget = CarrierBudget(inAll: 3);
    final a = budget.daemonOf('a');
    final b = budget.daemonOf('b');
    final streams = [ask(a, stream), ask(b, stream), ask(b, stream)];
    await settle();
    expect([for (final each in streams) each.got.length], [1, 1, 0], reason: 'the last place is kept for a call');
    final asked = ask(a, call);
    await settle();
    expect(asked.got, hasLength(1), reason: 'a call passes while a stream waits');
    asked.got.single!.leave();
    streams.first.got.single!.leave();
    await settle();
    expect(streams.last.got, hasLength(1), reason: 'the waiting stream is admitted once a stream gave its place back');
  });

  test('a wait abandoned is never admitted and keeps no place', () async {
    final budget = CarrierBudget(inAll: 2, daemonCalls: 2);
    final relays = budget.daemonOf('box');
    expect([budget.take(), budget.take()], [isTrue, isTrue], reason: 'carried connections hold every place of all');
    final leaving = Completer<void>();
    final abandoned = ask(relays, call, abandoned: leaving.future);
    final second = ask(relays, call);
    final third = ask(relays, call);
    await settle();
    leaving.complete();
    expect(await abandoned.asked, isNull, reason: 'a wait abandoned answers no place');
    budget
      ..giveBack()
      ..giveBack();
    await settle();
    expect(second.got, hasLength(1), reason: 'the next one waiting is admitted, not the abandoned one');
    expect(third.got, hasLength(1), reason: 'and the pool place the abandoned one held was given back');
  });

  test('a place given back twice counts once', () async {
    final budget = CarrierBudget(inAll: 2);
    final relays = budget.daemonOf('box');
    final first = ask(relays, call);
    await settle();
    first.got.single!
      ..leave()
      ..leave();
    expect(budget.take(), isTrue);
    expect(budget.take(), isTrue);
    expect(budget.take(), isFalse, reason: 'a second leave frees no place it did not hold');
  });

  test('a pool too small to keep a place for calls beside a stream is refused', () {
    expect(() => CarrierBudget(daemonCalls: 1), throwsArgumentError);
  });
}
