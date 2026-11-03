import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/organization_access_dialogs.dart';

void main() {
  // Harm: a trust decision raised by a timer, with the key already chosen, is one a person clicks through unasked.
  test('a read nobody asked for does not ask about a host key', () async {
    var shown = 0;
    final asking = ForgeTrustAsking((_) async {
      shown++;
      return true;
    });
    await asking.quietly(() async => expect(await asking.ask('forge.example.org'), isFalse));
    expect(shown, 0);
    expect(await asking.ask('forge.example.org'), isTrue);
    expect(shown, 1);
  });

  // Harm: reads side by side stack one dialog on another for the same host.
  test('reads side by side share one question', () async {
    final answer = Completer<bool>();
    var shown = 0;
    final asking = ForgeTrustAsking((_) {
      shown++;
      return answer.future;
    });
    final both = [asking.ask('forge.example.org'), asking.ask('forge.example.org')];
    answer.complete(true);
    expect(await Future.wait(both), [true, true]);
    expect(shown, 1);
  });
}
