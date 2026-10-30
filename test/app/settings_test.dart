import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/settings.dart';

void main() {
  // Harm: resuming obsolete setup can reuse retired credentials on a billed host.
  test('an old rental survives restart but cannot supply setup arguments', () async {
    final legacy = <String, Object?>{
      'scalewayProject': 'provider-project',
      'account': 'worker',
      'tresor': '',
      'folder': null,
      'signingKey': '',
      'identity': '/keys/private',
      'publicKey': '/keys/public.pub',
      'collection': '',
      'vpnPeerPublicKey': '',
      'vpnPeerAddress': '',
    };
    final store = MemorySettingsStore({
      'hostUps': {'demo': legacy},
    });
    final settings = Settings(store);
    addTearDown(settings.dispose);
    await settings.load();
    await settings.rememberHostUp('demo', settings.hostUp('demo')!);
    final reopened = Settings(store);
    addTearDown(reopened.dispose);
    await reopened.load();
    final record = reopened.hostUp('demo');
    expect(record, isNotNull, reason: 'a paid rental must keep its recovery data');
    expect(record!.scalewayProject, 'provider-project');
    expect(
      () => record.arguments('demo'),
      throwsStateError,
      reason: 'old credentials must never resume obsolete setup',
    );
  });

  // Harm: corrupt retired trust fields must not hide a billed rental or revive old credentials.
  test('legacy variants retain only the validated provider and rental identity', () async {
    for (final extra in [
      <String, Object?>{},
      {'hostName': 'orchard', 'host': 'orchard'},
      {'vpnPeerPublicKey': 7, 'forgeCa': 'broken', 'protocol': 'broken'},
      {'preparing': true, 'startedAt': 'broken'},
    ]) {
      final raw = <String, Object?>{'scalewayProject': 'provider', 'account': 'worker', ...extra};
      final record = HostUpRecord.fromStored(raw);
      expect(record, isNotNull, reason: 'optional old metadata cannot erase the provider recovery identity');
      final copy = HostUpRecord.fromStored(record!.stored)!;
      expect(copy.legacy, isTrue);
      expect(copy.giveBackArguments('demo'), containsAllInOrder(['--scaleway-project', 'provider', '--legacy-rental']));
      expect(copy.stored.keys, isNot(contains('forgeCa')));
      expect(copy.stored.keys, isNot(contains('identity')));
    }
    for (final bad in <Object?>[null, '', 7, '-option', 'provider\nother']) {
      expect(
        HostUpRecord.fromStored({'scalewayProject': bad}),
        isNull,
        reason: 'the provider identifier must be validated before give-back',
      );
    }
  });

  // Harm: a renamed settings key must not release the wrong rental and lose a billed server.
  test('a migrated project rental keeps its provider tag through restart', () async {
    final store = MemorySettingsStore({
      'hostUps': {
        'demo': {'scalewayProject': 'provider', 'account': 'worker', 'setupFolder': '/config/hosts/orchard'},
      },
      'machines': [
        {'name': 'old server', 'kind': 'host', 'hostProject': 'demo', 'socket': ''},
      ],
    });
    final settings = Settings(store);
    addTearDown(settings.dispose);
    await settings.load();
    final reopened = Settings(store);
    addTearDown(reopened.dispose);
    await reopened.load();
    final record = reopened.hostUp('orchard')!;
    expect(
      record.rentalTagFor('orchard'),
      'porelo-project=demo',
      reason: 'the provider still bills the original project tag',
    );
    expect(record.giveBackArguments('orchard'), containsAllInOrder(['--rental-tag', 'porelo-project=demo']));
  });

  // Harm: a retained rental with no private key must not look like a usable new host.
  test('an empty-identity legacy machine explains recovery after migration', () async {
    final settings = Settings(
      MemorySettingsStore({
        'hostUps': {
          'demo': {'scalewayProject': 'provider', 'setupFolder': '/config/hosts/orchard'},
        },
        'machines': [
          {'name': 'old server', 'kind': 'host', 'hostProject': 'demo', 'socket': ''},
        ],
      }),
    );
    addTearDown(settings.dispose);
    await settings.load();
    final machine = (await settings.machines()).single;
    expect(machine.hostProject, 'orchard');
    expect(machine.whyNotReachableHere, HostUpRecord.legacyExplanation);
  });

  // Harm: ambiguous migration must not collapse two independently billed rentals.
  test('conflicting legacy folders preserve both rental records on restart', () async {
    final record = {'scalewayProject': 'provider', 'setupFolder': '/config/hosts/shared'};
    final store = MemorySettingsStore({
      'hostUps': {'one': record, 'two': record},
    });
    final settings = Settings(store);
    addTearDown(settings.dispose);
    await settings.load();
    expect(settings.hostUps.keys, ['one', 'two']);
    await settings.rememberHostUp('one', settings.hostUp('one')!);
    final reopened = Settings(store);
    addTearDown(reopened.dispose);
    await reopened.load();
    expect(reopened.hostUps.keys, ['one', 'two']);
  });

  test('tresor folders are kept separately and invalid stored fields are ignored', () async {
    final store = MemorySettingsStore(<String, Object?>{
      'tresorFolders': <Object?, Object?>{'demo': '/first', 'bad': 7, 9: '/wrong', 'empty': '', 'nul': '/a\x00b'},
    });
    final settings = Settings(store);
    await settings.load();
    expect(settings.tresorFolder('demo'), '/first');
    for (final name in ['bad', '9', 'empty', 'nul']) {
      expect(settings.tresorFolder(name), isNull);
    }
    await settings.rememberTresorFolder('other', '/second');
    await settings.rememberTresorFolder('demo', '/changed');
    final again = Settings(store);
    await again.load();
    expect(again.tresorFolder('demo'), '/changed');
    expect(again.tresorFolder('other'), '/second');
    await again.rememberTresorFolder('demo', null);
    final last = Settings(store);
    await last.load();
    expect(last.tresorFolder('demo'), isNull);
    expect(last.tresorFolder('other'), '/second');
  });

  // Harm: a host's key goes into a file the person did not choose, or one they let go is opened again.
  test(
    'the secrets file is kept by its path, a relative or broken one is ignored, and letting it go is kept',
    () async {
      final store = MemorySettingsStore(<String, Object?>{'secretsFile': 'relative.kdbx'});
      final settings = Settings(store);
      await settings.load();
      expect(settings.secretsFile, isNull);
      await settings.rememberSecretsFile('/home/person/Porelo/secrets.kdbx');
      final again = Settings(store);
      await again.load();
      expect(again.secretsFile, '/home/person/Porelo/secrets.kdbx');
      await again.rememberSecretsFile(null);
      final last = Settings(store);
      await last.load();
      expect(last.secretsFile, isNull);
    },
  );

  test('new machines run work as agent until somebody says otherwise, and it is kept', () async {
    final store = MemorySettingsStore();
    final settings = Settings(store);
    expect(settings.workUser, 'agent');

    await settings.setWorkUser('builder');

    final again = Settings(store);
    await again.load();
    expect(again.workUser, 'builder');
  });

  test('a name no Linux machine would accept is never kept', () async {
    final settings = Settings(MemorySettingsStore());

    for (final wrong in <String>['Root', 'with space', '9lives', '', "a'b", 'x' * 33]) {
      await settings.setWorkUser(wrong);
      expect(settings.workUser, 'agent', reason: '"$wrong" was kept');
    }
  });

  test('a wrong name stored by hand reads as the default', () async {
    final settings = Settings(MemorySettingsStore(<String, Object?>{'workUser': "x'; rm -rf /"}));

    await settings.load();

    expect(settings.workUser, 'agent');
  });

  // The harm: a second entry of one name, written by hand, was watched beside the first, so calls
  // meant for one machine went through the other's tunnel.
  test('a second machine of a name already read is dropped, the first kept', () async {
    final settings = Settings(
      MemorySettingsStore(<String, Object?>{
        'machines': <Map<String, Object?>>[
          <String, Object?>{'name': 'vm', 'socket': '/tmp/first.sock'},
          <String, Object?>{'name': 'vm', 'socket': '/tmp/second.sock'},
          <String, Object?>{'name': 'other', 'socket': '/tmp/other.sock'},
        ],
      }),
    );

    final machines = await settings.machines();

    expect(
      [for (final each in machines) '${each.name} ${each.socketPath}'],
      <String>['vm /tmp/first.sock', 'other /tmp/other.sock'],
    );
  });

  // The harm: what a later version or another reader of the file wrote at its top level was lost
  // at the next save.
  test('a key this version does not know is kept when the settings are written', () async {
    final store = MemorySettingsStore(<String, Object?>{
      'fromLater': <String, Object?>{'kept': true},
      'workUser': 'agent',
    });
    final settings = Settings(store);
    await settings.load();

    await settings.setRefreshSeconds(30);

    final written = await store.read();
    expect(written['fromLater'], <String, Object?>{'kept': true});
    expect(written['refreshSeconds'], 30);
  });
}
