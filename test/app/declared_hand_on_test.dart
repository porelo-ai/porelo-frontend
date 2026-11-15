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

  // Harm: a project that waits again after the host took the token is never handed it by itself again.
  test('a project the host stopped reporting waiting waits anew', () async {
    final given = <String>[];
    final handOn = DeclaredHandOn((host) async {
      given.add(host);
      return const HandOn(HandOnOutcome.handedOn);
    });
    addTearDown(handOn.dispose);

    await handOn.forWaits('build', {'demo'});
    handOn.heard('build', {'demo'});
    expect((await handOn.forWaits('build', {'demo'})).earlier, isTrue, reason: 'still the same wait');
    handOn.heard('build', {});
    expect((await handOn.forWaits('build', {'demo'})).earlier, isFalse);
    expect(given, ['build', 'build'], reason: 'reported waiting again, it is handed on once more');
  });

  // Harm: a hand-over that could not run, a press giving to the host meanwhile, counts as the wait's answer, so the
  // declared token is never handed on for it.
  test('a hand-over that could not run answers nothing', () async {
    final outcomes = [
      const HandOn(HandOnOutcome.notRun, words: 'A token is being given to build already.'),
      const HandOn(HandOnOutcome.handedOn),
    ];
    final given = <String>[];
    final handOn = DeclaredHandOn((host) async {
      given.add(host);
      return outcomes.removeAt(0);
    });
    addTearDown(handOn.dispose);

    expect((await handOn.forWaits('build', {'demo'})).outcome, HandOnOutcome.notRun);
    final next = await handOn.forWaits('build', {'demo'});
    expect((next.outcome, next.earlier), (HandOnOutcome.handedOn, false), reason: 'the same wait is handed on now');
    expect(given, ['build', 'build']);
    expect((await handOn.forWaits('build', {'demo'})).earlier, isTrue);
  });
}
