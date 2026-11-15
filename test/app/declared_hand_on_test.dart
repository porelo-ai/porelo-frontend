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

    final first = handOn.forWaits('build', {'demo'});
    final joined = handOn.forWaits('build', {'demo', 'other'});
    expect(handOn.running('build'), isTrue);
    release.complete();
    expect((await first).outcome, HandOnOutcome.handedOn);
    expect((await joined).outcome, HandOnOutcome.handedOn);
    expect(given, ['build'], reason: 'two waits heard together hand on once');
    expect(handOn.running('build'), isFalse);

    expect((await handOn.forWaits('build', {'demo'})).outcome, HandOnOutcome.answeredBefore);
    expect(given, ['build'], reason: 'a wait answered before is not answered again by itself');
    expect((await handOn.forWaits('build', {'demo', 'third'})).outcome, HandOnOutcome.handedOn);
    expect(given, ['build', 'build'], reason: 'a project heard waiting later is a new wait');
    expect((await handOn.forWaits('build', {})).outcome, HandOnOutcome.answeredBefore);
    expect((await handOn.forWaits('lab', {'demo'})).outcome, HandOnOutcome.handedOn);
    expect(given, ['build', 'build', 'lab'], reason: 'each host waits for itself');
  });
}
