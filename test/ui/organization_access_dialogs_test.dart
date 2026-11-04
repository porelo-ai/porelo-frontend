import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/core_credentials.dart';
import 'package:porelo_frontend/src/app/device_key.dart';
import 'package:porelo_frontend/src/app/forge.dart';
import 'package:porelo_frontend/src/app/forge_connection.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/ui/organization_access_dialogs.dart';

import '../features/support/world.dart' show FakeBackend, World;

void main() {
  Future<BuildContext> page(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (here) {
            context = here;
            return const Scaffold();
          },
        ),
      ),
    );
    return context;
  }

  // Harm: a bare forge URL throws an Error past the change handler and leaves organization changes busy forever.
  testWidgets('an incomplete repository address refuses before any vault or token access', (tester) async {
    final context = await page(tester);
    final backend = FakeBackend([]);
    final tokens = _CountingTokens();
    final forges = ForgeConnection(tokens);
    addTearDown(forges.dispose);
    for (final repository in [
      'https://forge.example.org',
      'https://forge.example.org/acme',
      'ssh://git@forge.example.org',
    ]) {
      await expectLater(
        prepareOrganizationForge(
          context,
          repository,
          forges,
          localBackend: backend,
          deviceKeys: MemoryDeviceKeyStore(),
        ),
        throwsA(isA<OrganizationRefused>()),
      );
    }
    expect(backend.storeAsked, isEmpty);
    expect(tokens.reads, 0);
  });

  // Harm: a configured forge on another HTTPS port is blocked, or receives a token meant for the default port.
  testWidgets('an explicit forge port uses only its existing declared token', (tester) async {
    final context = await page(tester);
    final backend = FakeBackend([])
      ..theStoreIs = const VaultState(vault: '/vault', exists: true, readable: true, credentials: []);
    backend.theConnections = const [
      Connection(
        id: 'custom-forge',
        kind: 'TOKEN',
        match: 'https://forge.example.org:8443',
        purpose: 'git',
        source: 'VAULT',
        present: true,
      ),
    ];
    final tokens = _CountingTokens();
    final forges = ForgeConnection(tokens);
    addTearDown(forges.dispose);
    await prepareOrganizationForge(
      context,
      'https://forge.example.org:8443/acme/access.git',
      forges,
      localBackend: backend,
      deviceKeys: MemoryDeviceKeyStore(),
    );
    backend.theConnections = [];
    await expectLater(
      prepareOrganizationForge(
        context,
        'https://forge.example.org:8443/acme/access.git',
        forges,
        localBackend: backend,
        deviceKeys: MemoryDeviceKeyStore(),
      ),
      throwsA(isA<OrganizationRefused>()),
    );
    expect(tokens.reads, 0, reason: 'a port-specific destination must never take the default port token');
  });

  // Harm: a preview or a canceled comparison records a key; a failed confirmation is treated as trusted.
  testWidgets('trust records only after a deliberate comparison and keeps an exit 70 refusal open', (tester) async {
    final context = await page(tester);
    final fingerprint = 'SHA256:${List.filled(43, 'A').join()}';
    final calls = <List<String>>[];
    var recordCode = 70;
    final core = CoreCredentials(
      run: (_, arguments, {inDirectory, environment = const {}, input}) async {
        calls.add(arguments);
        final writing = arguments.any((argument) => argument.startsWith('--fingerprint='));
        return (
          code: writing ? recordCode : 0,
          out: jsonEncode(
            writing
                ? {
                    'host': 'forge.example.org',
                    'recorded': {'type': 'ssh-ed25519', 'fingerprint': fingerprint},
                  }
                : {
                    'host': 'forge.example.org',
                    'keys': [
                      {'type': 'ssh-ed25519', 'fingerprint': fingerprint},
                    ],
                    'known': false,
                  },
          ),
          err: '',
        );
      },
    );
    bool? trusted;
    unawaited(trustOrganizationForge(context, 'forge.example.org', core: core).then((value) => trusted = value));
    await World.settle(tester);
    expect(calls, hasLength(1));
    await tester.tap(find.text('Cancel'));
    await World.settle(tester);
    expect(trusted, false);
    expect(calls, hasLength(1), reason: 'cancel must record nothing');
    unawaited(trustOrganizationForge(context, 'forge.example.org', core: core).then((value) => trusted = value));
    await World.settle(tester);
    await tester.tap(find.text('Trust it'));
    await World.settle(tester);
    expect(find.text('Cancel'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Trust it')).onPressed, isNull);
    expect(trusted, false, reason: 'an unconfirmed recording must not complete the dialog as trusted');
    await tester.tap(find.text('Cancel'));
    await World.settle(tester);
    recordCode = 0;
    unawaited(trustOrganizationForge(context, 'forge.example.org', core: core).then((value) => trusted = value));
    await World.settle(tester);
    await tester.tap(find.text('Trust it'));
    await World.settle(tester);
    expect(trusted, true);
    expect(calls.last, ['credentials', 'trust-host', 'forge.example.org', '--fingerprint=$fingerprint', '--json']);
  });

  // Harm: a shut vault is treated as empty and a token is read or handed over before the person opens it.
  testWidgets('a shut vault asks first and cancel hands over no token', (tester) async {
    final context = await page(tester);
    final backend = FakeBackend([])
      ..theStoreIs = const VaultState(vault: '/vault', exists: true, readable: false, credentials: []);
    final tokens = _CountingTokens();
    await tokens.write('forge.example.org', 'private-test-token');
    final forges = ForgeConnection(tokens);
    addTearDown(forges.dispose);
    var puts = 0;
    final core = CoreCredentials(
      run: (_, _, {inDirectory, environment = const {}, input}) async {
        puts++;
        return (code: 0, out: '{}', err: '');
      },
    );
    Object? failure;
    unawaited(
      prepareOrganizationForge(
        context,
        'git@forge.example.org:acme/access.git',
        forges,
        localBackend: backend,
        deviceKeys: MemoryDeviceKeyStore(),
        core: core,
      ).catchError((Object error) {
        failure = error;
      }),
    );
    await World.settle(tester);
    expect(find.byKey(const Key('vault-act')), findsOneWidget);
    expect(tokens.reads, 0, reason: 'the vault decision precedes even reading the token');
    expect(puts, 0);
    await tester.tap(find.text('Cancel'));
    await World.settle(tester);
    expect(failure, isNotNull);
    expect(tokens.reads, 0);
    expect(puts, 0);
  });

  group('a forge whose credentials.yml entry holds no token', () {
    const match = 'https://forge.example.org/acme/';
    Connection entry({required String source, required String id}) =>
        Connection(id: id, kind: 'TOKEN', match: match, purpose: 'git', source: source);

    Future<({Future<void> prepared, FakeBackend backend, _CountingTokens tokens})> asked(
      WidgetTester tester,
      Connection connection, {
      List<Credential> held = const [],
    }) async {
      final context = await page(tester);
      final backend = FakeBackend([])
        ..theStoreIs = VaultState(vault: '/vault', exists: true, readable: true, credentials: held)
        ..theConnections = [connection];
      final tokens = _CountingTokens();
      final forges = ForgeConnection(tokens);
      addTearDown(forges.dispose);
      final prepared = prepareOrganizationForge(
        context,
        'https://forge.example.org/acme/access.git',
        forges,
        localBackend: backend,
        deviceKeys: MemoryDeviceKeyStore(),
      );
      await World.settle(tester);
      return (prepared: prepared, backend: backend, tokens: tokens);
    }

    // Harm: a person asked "check that credential" knows neither which one, nor where it is, nor what to do.
    for (final (source, id, said, next) in const [
      (
        'ENVIRONMENT',
        'FORGE_TOKEN',
        'the variable FORGE_TOKEN',
        'Set FORGE_TOKEN for the porelod service and for this window',
      ),
      ('FILE', '/keys/forge', 'the file /keys/forge', 'Put the token in /keys/forge'),
      ('VAULT', 'forge-work', 'the vault entry forge-work', 'Store the token in the vault as forge-work'),
    ]) {
      testWidgets('it says the entry, the address, $said and what to do; Cancel refuses with the same words', (
        tester,
      ) async {
        final open = await asked(tester, entry(source: source, id: id));
        Object? failure;
        unawaited(open.prepared.catchError((Object error) => failure = error));
        await tester.tap(find.text('Cancel'), warnIfMissed: false);
        expect(find.textContaining(said), findsOneWidget);
        expect(find.textContaining(next), findsOneWidget);
        await World.settle(tester);
        expect(
          failure,
          isA<OrganizationRefused>()
              .having((it) => it.words, 'names the file', contains('credentials.yml'))
              .having((it) => it.words, 'names the address', contains(match))
              .having((it) => it.words, 'names where', contains(said))
              .having((it) => it.words, 'says what to do', contains(next))
              .having((it) => it.words, 'says where to change it', contains('under Connections'))
              .having((it) => it.words, 'no unexplained word', isNot(contains('declared'))),
        );
        expect(open.backend.declared, isEmpty);
        expect(open.tokens.reads, 0);
      });
    }

    // Harm: an existing port entry whose token is only missing is called absent, and a person adds it again in vain.
    testWidgets('a forge port with its entry says the token is missing, not the entry', (tester) async {
      final context = await page(tester);
      final backend = FakeBackend([])
        ..theStoreIs = const VaultState(vault: '/vault', exists: true, readable: true, credentials: [])
        ..theConnections = const [
          Connection(
            id: 'git.token.forge.example.org',
            kind: 'TOKEN',
            match: 'https://forge.example.org:8443',
            purpose: 'git',
            source: 'VAULT',
          ),
        ];
      final forges = ForgeConnection(_CountingTokens());
      addTearDown(forges.dispose);
      await expectLater(
        prepareOrganizationForge(
          context,
          'https://forge.example.org:8443/acme/access.git',
          forges,
          localBackend: backend,
          deviceKeys: MemoryDeviceKeyStore(),
        ),
        throwsA(
          isA<OrganizationRefused>()
              .having((it) => it.words, 'says what to store', contains('vault as git.token.forge.example.org'))
              .having((it) => it.words, 'does not call it absent', isNot(contains('no entry'))),
        ),
      );
    });

    // Harm: the vault offer stops at the entry and the token the person has never reaches the vault.
    testWidgets('Take it from the vault goes on to hand over a token the vault lacks', (tester) async {
      final context = await page(tester);
      final backend = FakeBackend([])
        ..theStoreIs = const VaultState(vault: '/vault', exists: true, readable: true, credentials: [])
        ..theConnections = [entry(source: 'ENVIRONMENT', id: 'FORGE_TOKEN')];
      final tokens = _CountingTokens();
      await tokens.write('forge.example.org', 'private-test-token');
      final forges = ForgeConnection(tokens);
      addTearDown(forges.dispose);
      final calls = <List<String>>[];
      final core = CoreCredentials(
        run: (_, arguments, {inDirectory, environment = const {}, input}) async {
          calls.add(arguments);
          backend.theStoreIs = const VaultState(
            vault: '/vault',
            exists: true,
            readable: true,
            credentials: [Credential(name: 'git.token.forge.example.org', type: 'token', characters: 18)],
          );
          return (code: 0, out: '{"name":"git.token.forge.example.org","stored":true}', err: '');
        },
      );
      final prepared = prepareOrganizationForge(
        context,
        'https://forge.example.org/acme/access.git',
        forges,
        localBackend: backend,
        deviceKeys: MemoryDeviceKeyStore(),
        core: core,
      );
      await World.settle(tester);
      await tester.tap(find.text('Take it from the vault'));
      await World.settle(tester);
      await prepared;
      expect(backend.declared.single.source, 'VAULT');
      expect(calls.single, ['vault', 'put', 'git.token.forge.example.org', '--json']);
    });

    // Harm: a person must edit a file by hand although the window could change the entry, or the entry loses its
    // purpose, or the wrong vault entry is named, and the token is then looked for where it is not.
    testWidgets('Take it from the vault changes that entry and goes on', (tester) async {
      final open = await asked(
        tester,
        entry(source: 'ENVIRONMENT', id: 'FORGE_TOKEN'),
        held: const [Credential(name: 'git.token.forge.example.org', type: 'token', characters: 18)],
      );
      await tester.tap(find.text('Take it from the vault'));
      await World.settle(tester);
      await open.prepared;
      final changed = open.backend.declared.single;
      expect(changed.kind, 'TOKEN');
      expect(changed.match, match);
      expect(changed.id, 'git.token.forge.example.org');
      expect(changed.source, 'VAULT');
      expect(changed.purpose, 'git');
      expect(open.tokens.reads, 0, reason: 'the vault already holds it');
    });
  });

  // Harm: "needs its own declared token" says neither which address it means nor what a person does about it.
  testWidgets('a forge on its own port says which address needs an entry, and where to add it', (tester) async {
    final context = await page(tester);
    final tokens = _CountingTokens();
    final forges = ForgeConnection(tokens);
    addTearDown(forges.dispose);
    for (final connections in const [
      <Connection>[],
      [Connection(id: 'wide', kind: 'TOKEN', match: 'https://forge.example.org', purpose: 'git', source: 'VAULT')],
    ]) {
      final backend = FakeBackend([])
        ..theStoreIs = const VaultState(vault: '/vault', exists: true, readable: true, credentials: [])
        ..theConnections = connections;
      await expectLater(
        prepareOrganizationForge(
          context,
          'https://forge.example.org:8443/acme/access.git',
          forges,
          localBackend: backend,
          deviceKeys: MemoryDeviceKeyStore(),
        ),
        throwsA(
          isA<OrganizationRefused>()
              .having((it) => it.words, 'names the address', contains('https://forge.example.org:8443'))
              .having((it) => it.words, 'says where to add it', contains('under Connections'))
              .having((it) => it.words, 'no unexplained word', isNot(contains('declared'))),
        ),
      );
    }
  });

  // Harm: an ssh port is told to add a token for an address no token lookup ever asks for, and it never works.
  testWidgets('a forge reached by ssh on its own port is told to use its https address', (tester) async {
    final context = await page(tester);
    final forges = ForgeConnection(_CountingTokens());
    addTearDown(forges.dispose);
    await expectLater(
      prepareOrganizationForge(
        context,
        'ssh://git@forge.example.org:2222/acme/access.git',
        forges,
        localBackend: FakeBackend([])
          ..theStoreIs = const VaultState(vault: '/vault', exists: true, readable: true, credentials: []),
        deviceKeys: MemoryDeviceKeyStore(),
      ),
      throwsA(
        isA<OrganizationRefused>()
            .having((it) => it.words, 'says the way', contains('its https address'))
            .having((it) => it.words, 'promises no entry', isNot(contains('under Connections'))),
      ),
    );
  });

  // Harm: the address may carry a password, which must not reach a dialog; and a person is not told what to write.
  testWidgets('an address it cannot read is refused with the forms it can, and is not repeated', (tester) async {
    final context = await page(tester);
    final tokens = _CountingTokens();
    final forges = ForgeConnection(tokens);
    addTearDown(forges.dispose);
    await expectLater(
      prepareOrganizationForge(
        context,
        'https://someone:private-word@forge.example.org/acme/access.git',
        forges,
        localBackend: FakeBackend([]),
        deviceKeys: MemoryDeviceKeyStore(),
      ),
      throwsA(
        isA<OrganizationRefused>()
            .having((it) => it.words, 'says the forms', contains('git@'))
            .having((it) => it.words, 'never repeats it', isNot(contains('private-word')))
            .having((it) => it.words, 'no unexplained word', isNot(contains('declared'))),
      ),
    );
  });

  // Harm: a kept vault token is overwritten, a token goes to another forge, or a claimed put is never observed.
  testWidgets('only a missing local forge token is copied and its presence is read back', (tester) async {
    final context = await page(tester);
    final backend = FakeBackend([])
      ..theStoreIs = const VaultState(vault: '/vault', exists: true, readable: true, credentials: []);
    final tokens = _CountingTokens();
    await tokens.write('forge.example.org', 'private-test-token');
    final forges = ForgeConnection(tokens);
    addTearDown(forges.dispose);
    final calls = <List<String>>[];
    final core = CoreCredentials(
      run: (_, arguments, {inDirectory, environment = const {}, input}) async {
        calls.add(arguments);
        expect(input, 'private-test-token');
        backend.theStoreIs = const VaultState(
          vault: '/vault',
          exists: true,
          readable: true,
          credentials: [Credential(name: 'git.token.forge.example.org', type: 'token', characters: 18)],
        );
        return (code: 0, out: '{"name":"git.token.forge.example.org","stored":true}', err: '');
      },
    );
    await prepareOrganizationForge(
      context,
      'git@forge.example.org:acme/access.git',
      forges,
      localBackend: backend,
      deviceKeys: MemoryDeviceKeyStore(),
      core: core,
    );
    expect(calls.single, ['vault', 'put', 'git.token.forge.example.org', '--json']);
    expect(backend.storeAsked.where((call) => call == 'credentials'), hasLength(2));
    final reads = tokens.reads;
    await prepareOrganizationForge(
      context,
      'git@forge.example.org:acme/access.git',
      forges,
      localBackend: backend,
      deviceKeys: MemoryDeviceKeyStore(),
      core: core,
    );
    expect(calls, hasLength(1), reason: 'an existing token must never be replaced by the keychain token');
    expect(tokens.reads, reads);
  });
}

class _CountingTokens extends MemoryForgeTokens {
  int reads = 0;

  @override
  Future<String?> read(String forge) {
    reads++;
    return super.read(forge);
  }
}
