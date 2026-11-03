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
