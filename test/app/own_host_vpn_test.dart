import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/own_host_vpn.dart';
import 'package:porelo_frontend/src/app/run_here.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_host/porelo_host.dart';

import '../support/host_admin.dart';
import '../support/host_matrix_ca.dart';

void main() {
  final host = PreparedHost.read(matrixHostValues());
  final keys = (ssh: host.values['ssh_host_key']!, wireguard: wireGuardKey);
  late Settings settings;
  setUp(() => settings = Settings(MemorySettingsStore()));
  tearDown(() => settings.dispose());

  // Harm: an unverified VPN or failed trust installation must never create a usable host record.
  for (final failedStep in [0, 1]) {
    test('a refused VPN step $failedStep does not record the host', () async {
      final activations = <String?>[];
      var fetches = 0;
      await expectLater(
        connectOwnHostVpn(
          host: host,
          account: 'admin',
          keys: keys,
          address: '10.73.7.10',
          settings: settings,
          activate: (_, _, _, ca) async {
            activations.add(ca);
            return activations.length - 1 != failedStep;
          },
          fetchCa: () async {
            fetches++;
            return hostMatrixCa;
          },
        ),
        throwsA(isA<WorkspaceRefused>()),
      );
      expect(activations, failedStep == 0 ? [null] : [null, hostMatrixCa]);
      expect(fetches, failedStep);
      expect(settings.hostUp('orchard'), isNull);
    });
  }

  // Harm: sharing the flow must not make a verified join fetch or trust a different CA.
  test('a join uses its verified CA once and records only after the VPN succeeds', () async {
    var calls = 0;
    await connectOwnHostVpn(
      host: host,
      account: 'dev',
      keys: keys,
      address: '10.73.7.10',
      settings: settings,
      ca: hostMatrixCa,
      activate: (givenHost, givenKeys, address, ca) async {
        calls++;
        expect(givenHost, host);
        expect(givenKeys, keys);
        expect(address, '10.73.7.10');
        expect(ca, hostMatrixCa);
        expect(settings.hostUp('orchard'), isNull);
        return true;
      },
      fetchCa: () => throw StateError('A verified join must not fetch a CA.'),
    );
    expect(calls, 1);
    expect(settings.hostUp('orchard')!.forgeCa, hostMatrixCa);
    expect(settings.hostUp('orchard')!.account, 'dev');
  });

  // Harm: a substituted join CA must never be installed by the shared terminal.
  test('a supplied CA mismatch refuses before any VPN or record change', () async {
    var calls = 0;
    await expectLater(
      connectOwnHostVpn(
        host: PreparedHost.read({...matrixHostValues(), 'ca_sha256': '0' * 64}),
        account: 'dev',
        keys: keys,
        address: '10.73.7.10',
        settings: settings,
        ca: hostMatrixCa,
        activate: (_, _, _, _) async {
          calls++;
          return true;
        },
      ),
      throwsA(
        isA<WorkspaceRefused>().having(
          (error) => error.words,
          'fingerprints',
          allOf(contains('0' * 64), contains(hostMatrixCaSha256)),
        ),
      ),
    );
    expect(calls, 0);
    expect(settings.hostUp('orchard'), isNull);
  });

  // Harm: a linked trust file could authorize another host or overwrite unrelated trust.
  test('the CA fetch refuses a linked trust file before SSH', () async {
    final scratch = Directory.systemTemp.createTempSync('own-host-pin-');
    addTearDown(() => scratch.deleteSync(recursive: true));
    final unrelated = File('${scratch.path}/other')..writeAsStringSync('unrelated host');
    final trust = '${scratch.path}/known_hosts.orchard';
    Link(trust).createSync(unrelated.path);
    final remote = HelperRemote(response: hostMatrixCa);
    await expectLater(
      fetchOwnHostCa(host: host, account: 'admin', knownHosts: trust, remote: remote),
      throwsA(isA<WorkspaceRefused>()),
    );
    expect(remote.commands, isEmpty);
    expect(unrelated.readAsStringSync(), 'unrelated host');
  });

  // Harm: SSH diagnostics must not put credentials or untrusted remote text into a refusal.
  test('a failed CA fetch exposes no remote output or diagnostics', () async {
    final scratch = Directory.systemTemp.createTempSync('own-host-ca-');
    addTearDown(() => scratch.deleteSync(recursive: true));
    await expectLater(
      fetchOwnHostCa(
        host: host,
        account: 'admin',
        knownHosts: '${scratch.path}/known_hosts.orchard',
        remote: HelperRemote(code: 1, response: 'untrusted output', errors: 'untrusted diagnostics'),
      ),
      throwsA(
        isA<WorkspaceRefused>().having(
          (error) => error.words,
          'public refusal',
          allOf(isNot(contains('untrusted output')), isNot(contains('untrusted diagnostics'))),
        ),
      ),
    );
  });
}
