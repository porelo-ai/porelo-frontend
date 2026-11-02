import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/environment_tokens.dart';
import 'package:porelo_frontend/src/app/forge.dart';
import 'package:porelo_host/porelo_host.dart';

void main() {
  group('a forge token given to an instance', () {
    late MemoryForgeTokens store;
    const given = {forgeTokenVariable: 'the-token', forgeTokenForgeVariable: 'github.com'};

    setUp(() async {
      store = MemoryForgeTokens();
      await store.write('forge.example.org', 'its-own');
    });

    test('is read for its forge', () async {
      expect(await EnvironmentForgeTokens(given, store).read('github.com'), 'the-token');
    });

    // Harm: a person's GitHub token is sent to whatever other forge the interface asks.
    test('never goes to another forge', () async {
      final tokens = EnvironmentForgeTokens(given, store);
      expect(await tokens.read('forge.example.org'), 'its-own');
      expect(await tokens.read('gitlab.example.org'), isNull);
    });

    // Harm: a token with no forge named is taken for every forge's.
    for (final partial in [
      {forgeTokenVariable: 'the-token'},
      {forgeTokenForgeVariable: 'github.com'},
      {forgeTokenVariable: '', forgeTokenForgeVariable: 'github.com'},
    ]) {
      test('with only ${partial.keys.join(' and ')} set counts for nothing', () async {
        await store.write('github.com', 'in-the-store');
        expect(await EnvironmentForgeTokens(partial, store).read('github.com'), 'in-the-store');
      });
    }

    // Harm: a token typed seems kept, and is gone with the instance; or a person's stored token is deleted unasked.
    test('refuses to keep or delete for its forge, and leaves the store alone', () async {
      await store.write('github.com', 'in-the-store');
      final tokens = EnvironmentForgeTokens(given, store);
      await expectLater(tokens.write('github.com', 'typed'), throwsA(isA<ForgeRefused>()));
      await expectLater(tokens.delete('github.com'), throwsA(isA<ForgeRefused>()));
      expect(await store.read('github.com'), 'in-the-store');
    });

    test('keeps and deletes for another forge in the store', () async {
      final tokens = EnvironmentForgeTokens(given, store);
      await tokens.write('forge.example.org', 'new');
      expect(await store.read('forge.example.org'), 'new');
      await tokens.delete('forge.example.org');
      expect(await store.read('forge.example.org'), isNull);
    });
  });

  group('the central token', () {
    // Harm: a test instance asks a master password nobody is there to type.
    test('comes from the variable where it is set, even with a file chosen', () {
      final token = centralToken('/home/somebody/secrets.kdbx', {centralTokenVariable: 'x'});
      expect(token, isA<EnvironmentCentralToken>());
      expect((token! as EnvironmentCentralToken).variable, centralTokenVariable);
    });

    test('comes from the chosen file where the variable is empty or absent', () {
      for (final environment in [
        <String, String>{},
        {centralTokenVariable: ''},
      ]) {
        expect(centralToken('/home/somebody/secrets.kdbx', environment), isA<SecretsFile>());
      }
    });

    // Harm: push and pull are offered with nothing to feed them.
    test('has no source where neither is there', () {
      expect(centralToken(null, const {}), isNull);
    });
  });
}
