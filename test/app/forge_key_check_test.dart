import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/forge_key_check.dart';

Map<String, Object?> _answer({Object? keyListed = true, bool revoked = false, String? cardRefused}) => {
  'login': 'ms-test-reviewer',
  'name': 'MS Test Reviewer',
  'email': null,
  'fingerprint': 'SHA256:BvxPEq',
  'key': 'ssh-ed25519 AAAA',
  'agent': 'holds',
  'agent_holds_key': true,
  'revoked': revoked,
  'card_refused': cardRefused,
  'registry': <Object?>[],
  'forge': {
    'login': 'ms-test-reviewer',
    'key_listed': keyListed,
    'keys_url': 'https://github.com/ms-test-reviewer.keys',
    'account_url': 'https://github.com/settings/keys',
  },
  'pending': <Object?>[],
};

Future<ForgeKeyReading> _read(int code, Object answer, {List<List<String>>? calls}) => ForgeKeyCheckCli(
  run: (program, arguments, {inDirectory, environment = const {}, input}) async {
    calls?.add([program, ...arguments]);
    return (code: code, out: jsonEncode(answer), err: '');
  },
).read();

void main() {
  // Harm: a missing check would tell the person their key is on the forge when nobody could ask.
  test('a key listing that could not be asked reads as unknown, never as listed', () async {
    final reading = await _read(0, _answer(keyListed: null));
    expect(reading, isA<ForgeKeyAnswered>());
    expect((reading as ForgeKeyAnswered).forge!.listed, ForgeKeyListed.unknown);
    expect(reading.good, isFalse);
  });

  // Harm: an answer this interface does not know must not be guessed into "listed".
  test('an unknown or incomplete key listing is refused, not read as listed', () async {
    for (final listed in ['yes', 1, 'true']) {
      final reading = await _read(0, _answer(keyListed: listed));
      expect(reading, isA<ForgeKeyUnavailable>(), reason: '$listed');
      expect(reading.good, isFalse);
    }
    final missing = _answer();
    (missing['forge']! as Map<String, Object?>).remove('key_listed');
    expect(await _read(0, missing), isA<ForgeKeyUnavailable>());
    expect(await _read(0, _answer()..remove('card_refused')), isA<ForgeKeyUnavailable>());
    expect(await _read(0, _answer()..remove('forge')), isA<ForgeKeyUnavailable>());
  });

  // Harm: a revoked or refused card with its key on the forge must not read as a working identity.
  test('a revoked or refused card never reads as good, even with its key listed', () async {
    final revoked = await _read(0, _answer(revoked: true));
    expect(revoked.good, isFalse);
    expect((revoked as ForgeKeyAnswered).cardProblem, contains('revoked'));
    final refused = await _read(0, _answer(cardRefused: 'signature does not verify'));
    expect(refused.good, isFalse);
    expect((refused as ForgeKeyAnswered).cardProblem, contains('signature does not verify'));
  });

  // Harm: without a card or with an unknown refusal, nothing about the forge may read as good.
  test('no identity, an unknown refusal and other exits never read as good', () async {
    final none = await _read(65, {'reason': 'no-identity', 'words': 'No card is kept here.'});
    expect(none, isA<ForgeKeyNoIdentity>());
    expect(none.good, isFalse);
    expect(await _read(65, {'reason': 'something-else', 'words': 'x'}), isA<ForgeKeyUnavailable>());
    for (final code in [64, 66, 69, 70, 77, 1]) {
      final reading = await _read(code, _answer());
      expect(reading, isA<ForgeKeyUnavailable>(), reason: '$code');
      expect(reading.good, isFalse);
    }
  });

  // Harm: a forge address with user information would hand a credential to the browser.
  test('a forge address with user information is refused', () async {
    final answer = _answer();
    (answer['forge']! as Map<String, Object?>)['account_url'] = 'https://user:secret@github.com/settings/keys';
    expect(await _read(0, answer), isA<ForgeKeyUnavailable>());
  });

  // Harm: the read must be Core's identity verb as an argument list, and a listed key on a good card reads as good.
  test('a listed key on a good card is good, read from identity show as an argument list', () async {
    final calls = <List<String>>[];
    final reading = await _read(0, _answer(), calls: calls);
    expect(calls, [
      ['porelo', 'identity', 'show', '--json'],
    ]);
    expect(reading.good, isTrue);
    final forge = (reading as ForgeKeyAnswered).forge!;
    expect(forge.accountUrl, Uri.parse('https://github.com/settings/keys'));
    expect(forge.keysUrl, Uri.parse('https://github.com/ms-test-reviewer.keys'));
  });

  // Harm: without a known forge the page must say so instead of showing a check.
  test('no forge known reads as no check', () async {
    final reading = await _read(0, _answer()..['forge'] = null);
    expect((reading as ForgeKeyAnswered).forge, isNull);
    expect(reading.good, isFalse);
  });
}
