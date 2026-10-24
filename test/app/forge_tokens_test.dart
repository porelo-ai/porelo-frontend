import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/forge.dart';
import 'package:porelo_host/porelo_host.dart';

void main() {
  // Harm: separate store entries would make a terminal-entered token unusable by the API.
  test('the API reads and forgets the entry written by the host helper', () async {
    final store = _Store();
    await store.write(providerKeyName('Git.Example.org'), 'fixture-token');
    final tokens = PlatformForgeTokens(store: () => store);
    expect(await tokens.read('git.example.org'), 'fixture-token');
    expect(await tokens.read('other.example.org'), isNull);
    await tokens.delete('git.example.org');
    expect(await store.read(providerKeyName('git.example.org')), isNull);
    expect(store.closed, 3, reason: 'each API operation closes its own store connection');
  });

  // Harm: a forged settings entry must never send the Scaleway API key to a forge.
  test('a forge cannot read the reserved provider credential', () async {
    final store = _Store();
    await store.write(providerKeyName('scaleway'), 'provider-fixture');
    final tokens = PlatformForgeTokens(store: () => store);
    await expectLater(tokens.read('scaleway'), throwsA(isA<ForgeRefused>()));
    expect(store.readNames, isEmpty, reason: 'reject a provider name before looking up any credential');
  });

  // Harm: a store error that quotes its value must not expose the token in the interface.
  for (final failure in <Exception>[const SecretStoreFailed('fixture-token'), const SocketException('fixture-token')]) {
    test('a store refusal ${failure.runtimeType} never repeats a token', () async {
      final store = _Store()..failure = failure;
      final tokens = PlatformForgeTokens(store: () => store);
      await expectLater(
        tokens.read('github.com'),
        throwsA(isA<ForgeRefused>().having((error) => error.words, 'words', isNot(contains('fixture-token')))),
      );
      expect(store.closed, 1);
    });
  }
}

class _Store implements SecretStore {
  final values = <String, String>{};
  final readNames = <String>[];
  Exception? failure;
  int closed = 0;

  @override
  Future<String?> read(String name) async {
    readNames.add(name);
    if (failure case final error?) throw error;
    return values[name];
  }

  @override
  Future<void> write(String name, String value) async => values[name] = value;

  @override
  Future<void> remove(String name) async => values.remove(name);

  @override
  Future<void> close() async => closed++;
}
