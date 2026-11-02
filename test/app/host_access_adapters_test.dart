import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_access_adapters.dart';
import 'package:porelo_frontend/src/app/run_here.dart';

import '../support/host_organization.dart';

/// Core's `identity show --json` answer for alice, whose card key the agent holds.
Map<String, Object?> _shown({bool revoked = false, String? cardRefused, String agent = 'holds'}) => {
  'login': 'alice',
  'name': 'Alice',
  'email': 'alice@example.org',
  'fingerprint': adminFingerprint,
  'key': hostKey,
  'created': '2026-10-31',
  'expires': '2026-11-30',
  'predecessor': null,
  'card': 'login: "alice"\n',
  'agent': agent,
  'agent_holds_key': agent == 'holds',
  'revoked': revoked,
  'card_refused': cardRefused,
  'organization': <Object?>[],
  'forge': null,
  'pending': <Object?>[],
};

void main() {
  group('the proven identity', () {
    late List<List<String>> asked;
    late Ran answer;
    late CoreHostAdminProof proof;
    setUp(() {
      asked = [];
      answer = (code: 0, out: jsonEncode(_shown()), err: '');
      proof = CoreHostAdminProof(
        run: (program, arguments, {inDirectory, environment = const {}, input}) async {
          asked.add([program, ...arguments]);
          return answer;
        },
      );
    });

    // Harm: the host admin's right is taken from anything but Core's proven card.
    test('a usable card proves its login and fingerprint, read from Core', () async {
      await proof.readAgain();
      expect(asked, [
        ['porelo', 'identity', 'show', '--json'],
      ]);
      expect(proof.current()?.login, 'alice');
      expect(proof.current()?.fingerprint, adminFingerprint);
      expect(proof.whyNone, isNull);
    });

    // Harm: a revoked key, a refused card or a key the agent does not hold acts as a host admin.
    for (final (name, unusable) in [
      ('a revoked key', (code: 0, out: jsonEncode(_shown(revoked: true)), err: '')),
      ('a refused card', (code: 0, out: jsonEncode(_shown(cardRefused: 'bad signature')), err: '')),
      ('a key the agent does not hold', (code: 0, out: jsonEncode(_shown(agent: 'not-held')), err: '')),
      ('no card', (code: 65, out: jsonEncode({'reason': 'no-identity', 'words': 'No card is kept.'}), err: '')),
      ('an unreadable answer', (code: 0, out: 'not json', err: '')),
    ]) {
      test('$name proves nobody, even after a usable read, and says why', () async {
        await proof.readAgain();
        expect(proof.current(), isNotNull);
        answer = unusable;
        await proof.readAgain();
        expect(proof.current(), isNull);
        expect(proof.whyNone, isNotEmpty);
      });
    }
  });

  // Harm: an older read that ends last brings back a key revoked or taken out of the agent since.
  test('only the newest identity read is kept, and every read is announced', () async {
    final first = Completer<Ran>();
    var asked = 0;
    final proof = CoreHostAdminProof(
      run: (program, arguments, {inDirectory, environment = const {}, input}) async {
        asked++;
        return asked == 1 ? first.future : (code: 0, out: jsonEncode(_shown(revoked: true)), err: '');
      },
    );
    var announced = 0;
    proof.addListener(() => announced++);
    final older = proof.readAgain();
    await proof.readAgain();
    first.complete((code: 0, out: jsonEncode(_shown()), err: ''));
    await older;
    expect(proof.current(), isNull);
    expect(announced, 1);
  });
}
