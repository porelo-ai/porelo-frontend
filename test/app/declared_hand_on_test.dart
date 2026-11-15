import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/declared_hand_on.dart';

void main() {
  // Harm: a declared token that did not help is handed on again and again by itself, or two waits hand it on twice.
  test('a wait is handed on once, joined while it runs, and a new project is a new wait', () async {
    final given = <String>[];
    final release = Completer<void>();
    final handOn = DeclaredHandOn((host) async {
      given.add(host);
      await release.future;
      return const HandOn(HandOnOutcome.handedOn);
    });
    addTearDown(handOn.dispose);

    final first = handOn.forWaits('build', {'demo'});
    final joined = handOn.forWaits('build', {'demo', 'other'});
    expect(handOn.running('build'), isTrue);
    release.complete();
    expect((await first).outcome, HandOnOutcome.handedOn);
    expect((await joined).outcome, HandOnOutcome.handedOn);
    expect(given, ['build'], reason: 'two waits heard together hand on once');
    expect(handOn.running('build'), isFalse);

    final before = await handOn.forWaits('build', {'other'});
    expect((before.outcome, before.earlier), (HandOnOutcome.handedOn, true), reason: 'a joined wait was answered too');
    expect(given, ['build'], reason: 'a wait answered before is not answered again by itself');
    expect((await handOn.forWaits('build', {'demo', 'third'})).earlier, isFalse);
    expect(given, ['build', 'build'], reason: 'a project heard waiting later is a new wait');
    expect((await handOn.forWaits('build', {})).outcome, HandOnOutcome.nothingWaits);
    expect((await handOn.forWaits('lab', {'demo'})).earlier, isFalse);
    expect(given, ['build', 'build', 'lab'], reason: 'each host waits for itself');
  });

  // Harm: a project that waits again after the host took the token is never handed it by itself again, or one that
  // only passed through another state is handed the token that did not help once more.
  test('a project waits anew only once the host reported it taken', () async {
    final given = <String>[];
    final handOn = DeclaredHandOn((host) async {
      given.add(host);
      return const HandOn(HandOnOutcome.handedOn);
    });
    addTearDown(handOn.dispose);

    await handOn.forWaits('build', {'demo'});
    handOn.taken('build', {'other'});
    expect((await handOn.forWaits('build', {'demo'})).earlier, isTrue, reason: 'not taken: still the same wait');
    handOn.taken('build', {'demo'});
    expect((await handOn.forWaits('build', {'demo'})).earlier, isFalse);
    expect(given, ['build', 'build'], reason: 'taken and waiting again, it is handed on once more');
  });

  // Harm: a hand-over that could not run, a press giving to the host meanwhile, counts as the wait's answer, so the
  // declared token is never handed on for it; or it is tried again on every word of the host while the cause lasts.
  test('a hand-over that could not run answers nothing, and is tried again at most once a minute', () async {
    var now = DateTime.utc(2026, 11, 15, 18);
    final outcomes = [
      const HandOn(HandOnOutcome.notRun, words: 'A token is being given to build already.'),
      const HandOn(HandOnOutcome.notRun, words: 'A token is being given to build already.'),
      const HandOn(HandOnOutcome.handedOn),
    ];
    final given = <String>[];
    final handOn = DeclaredHandOn((host) async {
      given.add(host);
      return host == 'build' ? outcomes.removeAt(0) : const HandOn(HandOnOutcome.handedOn);
    }, now: () => now);
    addTearDown(handOn.dispose);

    expect((await handOn.forWaits('build', {'demo'})).outcome, HandOnOutcome.notRun);
    now = now.add(const Duration(seconds: 59));
    final soon = await handOn.forWaits('build', {'demo'});
    expect(
      (soon.outcome, soon.earlier, soon.words),
      (HandOnOutcome.notRun, true, 'A token is being given to build already.'),
    );
    expect((await handOn.forWaits('lab', {'demo'})).earlier, isFalse, reason: 'another host is its own');
    expect(given, ['build', 'lab'], reason: 'within the minute, not tried again');

    now = now.add(const Duration(seconds: 1));
    expect((await handOn.forWaits('build', {'demo'})).outcome, HandOnOutcome.notRun, reason: 'tried after a minute');
    now = now.add(const Duration(minutes: 1));
    final next = await handOn.forWaits('build', {'demo'});
    expect((next.outcome, next.earlier), (HandOnOutcome.handedOn, false), reason: 'the same wait is handed on now');
    expect(given, ['build', 'lab', 'build', 'build']);
    expect((await handOn.forWaits('build', {'demo'})).earlier, isTrue);
  });
}
