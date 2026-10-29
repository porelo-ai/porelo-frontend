import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:porelo_frontend/src/app/settings.dart';

void main() {
  // Harm: an invalid retention value can lose the record of a decision immediately or keep it indefinitely.
  test('resolved retention defaults to an hour and validates persisted minutes', () async {
    final store = MemorySettingsStore();
    final settings = Settings(store);
    expect(settings.keepResolvedMinutes, 60);
    await settings.setKeepResolvedMinutes(2);
    final reopened = Settings(store);
    await reopened.load();
    expect(reopened.keepResolvedMinutes, 2);
    await reopened.setKeepResolvedMinutes(0);
    await settings.load();
    expect(settings.keepResolvedMinutes, 0);
    for (final invalid in <Object?>[-1, '2', 2.5, true, null]) {
      final broken = Settings(MemorySettingsStore({'keepResolvedMinutes': invalid}));
      await broken.load();
      expect(broken.keepResolvedMinutes, 60);
    }
  });

  const record = <String, Object?>{
    'scalewayProject': 'provider-project',
    'account': 'worker',
    'tresor': 'drive',
    'folder': '/synced/drive',
    'signingKey': '/keys/sign.pub',
    'identity': '/keys/private',
    'publicKey': '/keys/public.pub',
    'collection': '/setup.tar.gz',
    'vpnPeerPublicKey': 'public-half',
    'vpnPeerAddress': '10.73.0.2/32',
  };

  // Harm: a corrupted saved-file field must not crash startup or be used as a root command input.
  test('a VPN file path survives reload while a wrong stored type is refused', () async {
    final store = MemorySettingsStore();
    final settings = Settings(store);
    await settings.rememberHostUp('demo', HostUpRecord.fromStored(record)!.withVpnFile('/private folder/porelo.conf'));
    final reopened = Settings(store);
    await reopened.load();
    expect(reopened.hostUp('demo')!.vpnFile, '/private folder/porelo.conf');
    expect(reopened.hostUp('demo')!.arguments('demo'), HostUpRecord.fromStored(record)!.arguments('demo'));
    expect(HostUpRecord.fromStored({...record, 'vpnFile': 7}), isNull);
    expect(HostUpRecord.fromStored(record)!.vpnFile, isNull, reason: 'older records remain usable');
  });

  // Harm: up uploads files from another place than the interface wrote them, or a resumed setup none at all.
  test('the setup folder survives reload and names the files up uploads; an older record names none', () async {
    final store = MemorySettingsStore();
    final settings = Settings(store);
    addTearDown(settings.dispose);
    // An absolute folder as this platform writes one, with a step the arguments must not keep.
    final conf = path.join(Directory.systemTemp.path, 'conf', 'hosts', 'demo');
    await settings.rememberHostUp('demo', HostUpRecord.fromStored({...record, 'setupFolder': path.join(conf, '.')})!);
    final reopened = Settings(store);
    addTearDown(reopened.dispose);
    await reopened.load();
    final arguments = reopened.hostUp('demo')!.arguments('demo');
    expect(arguments.skip(arguments.length - 4), [
      '--machine-file',
      path.join(conf, 'porelo-host', 'machine.yml'),
      '--bundle',
      path.join(conf, 'porelo-host', 'demo.bundle'),
    ]);
    expect(HostUpRecord.fromStored(record)!.arguments('demo'), isNot(contains('--machine-file')));
    for (final bad in <Object?>['relative/hosts', 7, path.join(conf, '\x00x')]) {
      expect(HostUpRecord.fromStored({...record, 'setupFolder': bad}), isNull, reason: '$bad');
    }
  });

  // Harm: one host's CA is installed for another host, lost during updates, or replaced by invalid trust data.
  test('each host keeps its CA across reload and record updates', () async {
    final store = MemorySettingsStore();
    final settings = Settings(store);
    addTearDown(settings.dispose);
    final ca =
        '-----BEGIN CERTIFICATE-----\n${base64Encode(List<int>.generate(48, (i) => i))}\n-----END CERTIFICATE-----\n';
    final otherCa = ca.replaceFirst('AAEC', 'AQEC');
    for (final (host, pem) in [('demo', ca), ('second', otherCa)]) {
      final hostRecord = HostUpRecord.fromStored({...record, 'forgeCa': pem})!;
      await settings.rememberHostUp(host, hostRecord);
    }
    final reopened = Settings(store);
    addTearDown(reopened.dispose);
    await reopened.load();
    expect(reopened.hostUp('demo')!.stored['forgeCa'], ca);
    expect(reopened.hostUp('second')!.stored['forgeCa'], otherCa);
    final kept = reopened.hostUp('demo')!;
    for (final updated in [
      kept.withPreparation(DateTime.utc(2026)),
      kept.withPreparation(null),
      kept.withVpnFile('/private/porelo.conf'),
      kept.withTunnel(hostPublicKey: '', address: ''),
      kept.withProtocol(const []),
    ]) {
      expect(updated.stored['forgeCa'], ca, reason: 'a public record update must preserve this host\'s trust');
    }
    for (final bad in <Object?>[7, '', '$ca$ca', '-----BEGIN CERTIFICATE-----\n\n-----END CERTIFICATE-----\n']) {
      expect(HostUpRecord.fromStored({...record, 'forgeCa': bad}), isNull, reason: 'invalid trust is refused');
    }
    expect(HostUpRecord.fromStored(record)!.stored['forgeCa'], isNull, reason: 'an older record has no trusted CA');
    await settings.rememberForgeCa('demo', otherCa);
    expect(settings.hostUp('demo')!.forgeCa, otherCa);
    expect(settings.hostUp('second')!.forgeCa, otherCa, reason: 'only the selected host changes');
    await settings.rememberForgeCa('demo', null);
    expect(settings.hostUp('demo')!.forgeCa, isNull);
    expect(settings.hostUp('second')!.forgeCa, otherCa);
    await expectLater(settings.rememberForgeCa('missing', ca), throwsArgumentError);
    await expectLater(settings.rememberForgeCa('demo', 'invalid'), throwsArgumentError);
  });

  // Harm: a certificate is constrained to the wrong network after reading the host's recorded peer.
  test('the host network number comes from its VPN peer and refuses invalid octets', () {
    for (final number in [0, 17, 255]) {
      expect(HostUpRecord.fromStored({...record, 'vpnPeerAddress': '10.73.$number.2/32'})!.vpnNetworkNumber, number);
    }
    expect(HostUpRecord.fromStored({...record, 'vpnPeerAddress': '', 'vpnPeerPublicKey': ''})!.vpnNetworkNumber, 0);
    for (final address in ['10.73.256.2/32', '10.73.17.256/32', '10.74.0.2/32', '10.73.0.2/24', 'invalid']) {
      expect(
        () => HostUpRecord.fromStored({...record, 'vpnPeerAddress': address})!.vpnNetworkNumber,
        throwsFormatException,
      );
    }
  });

  test('the vault entries\' names survive reload, and a name the stop would refuse drops the record', () async {
    final store = MemorySettingsStore();
    final settings = Settings(store);
    addTearDown(settings.dispose);
    await settings.rememberHostUp(
      'demo',
      HostUpRecord.fromStored({
        ...record,
        'vaultKeys': ['forge', 'ci.key'],
      })!,
    );
    final reopened = Settings(store);
    addTearDown(reopened.dispose);
    await reopened.load();
    expect(reopened.hostUp('demo')!.vaultKeys, ['forge', 'ci.key']);
    expect(HostUpRecord.fromStored(record)!.vaultKeys, isEmpty, reason: 'older records remain usable');
    for (final bad in <Object?>[
      'forge',
      ['a b'],
      ["a'b"],
      ['_x'],
      [7],
      ['forge', 'forge'],
    ]) {
      expect(HostUpRecord.fromStored({...record, 'vaultKeys': bad}), isNull, reason: '$bad');
    }
  });

  // Harm: saving or deleting a VPN file must not remove the digest that verifies the setup collection.
  test('changing the saved VPN path preserves the collection digest and host record', () async {
    final digest = List.filled(64, 'a').join();
    final original = HostUpRecord.fromStored({...record, 'collectionSha256': digest})!;
    final store = MemorySettingsStore();
    final settings = Settings(store);
    addTearDown(settings.dispose);
    for (final file in ['/private/porelo.conf', '/private/replacement.conf', null]) {
      final changed = original.withVpnFile(file);
      expect(changed.collectionSha256, digest);
      expect(changed.stored, {...original.stored, 'vpnFile': ?file});
      await settings.rememberHostUp('demo', changed);
      final reopened = Settings(store);
      await reopened.load();
      expect(reopened.hostUp('demo')!.collectionSha256, digest);
      reopened.dispose();
    }
  });

  // Harm: losing public tunnel settings across a restart strands a ready server without a VPN export.
  test('public host tunnel settings round-trip and survive changing or deleting the saved file', () async {
    final publicKey = base64Encode(List<int>.filled(32, 9));
    final original = HostUpRecord.fromStored(record)!.withTunnel(hostPublicKey: publicKey, address: '2001:db8::8');
    final store = MemorySettingsStore();
    final settings = Settings(store);
    addTearDown(settings.dispose);
    for (final file in ['/private/porelo.conf', null]) {
      await settings.rememberHostUp('demo', original.withVpnFile(file));
      final reopened = Settings(store);
      await reopened.load();
      final kept = reopened.hostUp('demo')!;
      expect(kept.vpnHostPublicKey, publicKey);
      expect(kept.vpnEndpointAddress, '2001:db8::8');
      expect(kept.stored, {...original.stored, 'vpnFile': ?file});
      reopened.dispose();
    }
  });

  // Harm: rejecting older setup records loses the server identity needed to take down a billing host.
  test('an older host record without public export settings still loads', () async {
    final legacy = {...record, 'repository': 'https://example.org/demo.git'};
    final settings = Settings(
      MemorySettingsStore({
        'hostUps': {'demo': legacy},
      }),
    );
    addTearDown(settings.dispose);
    await settings.load();
    final kept = settings.hostUp('demo')!;
    expect(kept.vpnHostPublicKey, isEmpty);
    expect(kept.vpnEndpointAddress, isEmpty);
    expect(kept.stored, record);
  });

  // Harm: malformed public tunnel settings can inject configuration or crash settings restoration.
  test('invalid stored public tunnel settings are refused', () {
    for (final invalid in <Object?>[7, true, [], 'not-a-key', 'key\n[Peer]']) {
      expect(HostUpRecord.fromStored({...record, 'vpnHostPublicKey': invalid}), isNull);
    }
    for (final invalid in <Object?>[7, true, [], 'address\nAllowedIPs=0.0.0.0/0', 'host:51820/path']) {
      expect(HostUpRecord.fromStored({...record, 'vpnEndpointAddress': invalid}), isNull);
    }
  });

  // Harm: missing host identity or setup inputs can redirect teardown or lose access to a billing server.
  test('stored host records with empty or whitespace-only required fields are dropped on load', () async {
    for (final field in ['scalewayProject', 'account', 'identity', 'publicKey']) {
      for (final empty in ['', ' \t\n ']) {
        final settings = Settings(
          MemorySettingsStore({
            'hostUps': {
              'valid': record,
              'broken': {...record, field: empty},
            },
          }),
        );
        await settings.load();
        expect(settings.hostUp('valid')!.stored, record, reason: 'complete records must remain usable');
        expect(settings.hostUp('broken'), isNull, reason: 'empty $field must discard the entire record');
      }
    }
  });

  // Harm: a record of a host set up since the drive left its setup dropped for naming no tresor, or one from
  // before passing its tresor to a collection that mounts no drive.
  test('a record with no tresor is kept, and no record passes one on', () async {
    final none = HostUpRecord.fromStored({...record, 'tresor': ''});
    expect(none, isNotNull);
    expect(none!.arguments('demo'), isNot(contains('--tresor')));
    expect(HostUpRecord.fromStored(record)!.arguments('demo'), isNot(contains('--tresor')), reason: 'one from before');
    expect(HostUpRecord.fromStored({...record, 'tresor': 'a\x00b'}), isNull);
  });

  // Harm: keeping only one tunnel option makes teardown run with a different host setup identity.
  test('stored host records with only one VPN peer option are dropped on load', () async {
    for (final field in ['vpnPeerPublicKey', 'vpnPeerAddress']) {
      final withoutTunnel = {...record, 'vpnPeerPublicKey': '', 'vpnPeerAddress': ''};
      final settings = Settings(
        MemorySettingsStore({
          'hostUps': {
            'valid': record,
            'withoutTunnel': withoutTunnel,
            'broken': {...record, field: ''},
          },
        }),
      );
      await settings.load();
      expect(settings.hostUp('valid')!.stored, record, reason: 'paired tunnel options must remain usable');
      expect(settings.hostUp('withoutTunnel')!.stored, withoutTunnel, reason: 'an absent tunnel is valid');
      expect(settings.hostUp('broken'), isNull, reason: 'missing $field must discard the entire record');
    }
  });

  // Harm: restoring a synced folder without its signing key leaves host setup incomplete.
  test('stored host records with a folder need a signing key on load', () async {
    for (final field in ['signingKey']) {
      for (final empty in ['', ' \t\n ']) {
        final manual = {...record, 'folder': null, 'signingKey': ''};
        final settings = Settings(
          MemorySettingsStore({
            'hostUps': {
              'valid': record,
              'manual': manual,
              'broken': {...record, field: empty},
            },
          }),
        );
        await settings.load();
        expect(settings.hostUp('valid')!.stored, record, reason: 'complete synced-folder records must remain usable');
        expect(settings.hostUp('manual')!.stored, manual, reason: 'manually supplied files need no local repository');
        expect(settings.hostUp('broken'), isNull, reason: 'a folder without $field must discard the entire record');
      }
    }
  });

  // Harm: a partial or mistyped setup record tears down a different server or loses access to it.
  test('host setup records survive reload per project and malformed records are dropped whole', () async {
    final store = MemorySettingsStore({
      'hostUps': {
        'demo': record,
        'other': {...record, 'account': 'other'},
      },
    });
    final settings = Settings(store);
    await settings.load();
    expect(settings.hostUp('demo')!.stored, record);
    await settings.rememberHostUp('third', settings.hostUp('demo')!);
    final reopened = Settings(store);
    await reopened.load();
    expect(reopened.hostUp('third')!.stored, record);
    expect(reopened.hostUp('other')!.account, 'other');
    expect(reopened.hostUp('absent'), isNull);
    final discarded = Settings(
      _DiscardedWritesStore({
        'hostUps': {'demo': record},
      }),
    );
    await discarded.load();
    final changed = HostUpRecord.fromStored({...record, 'scalewayProject': 'different-provider-project'})!;
    await expectLater(discarded.rememberHostUp('demo', changed), throwsA(isA<FileSystemException>()));
    expect(discarded.hostUp('demo')!.stored, record, reason: 'an unwritten change cannot redirect teardown');
    for (final field in record.keys) {
      for (final value in [7, <String>[], <String, Object?>{}, true, 'bad\x00value']) {
        final broken = Settings(
          MemorySettingsStore({
            'hostUps': {
              'demo': {...record, field: value},
            },
          }),
        );
        await broken.load();
        expect(broken.hostUp('demo'), isNull, reason: 'invalid $field must discard the entire record');
      }
      final missing = {...record}..remove(field);
      final broken = Settings(
        MemorySettingsStore({
          'hostUps': {'demo': missing},
        }),
      );
      await broken.load();
      expect(broken.hostUp('demo'), isNull, reason: 'missing $field must discard the entire record');
    }
  });

  // Harm: choosing another project's folder overwrites files in the wrong tresor.
  // Red: keep one global folder, omit it from _known, or cast malformed stored fields.
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

class _DiscardedWritesStore extends MemorySettingsStore {
  _DiscardedWritesStore(super.initial);

  @override
  Future<void> write(Map<String, Object?> values) async {}
}
