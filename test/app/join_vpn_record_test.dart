import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_host/porelo_host.dart';

import '../support/host_admin.dart';
import '../support/host_matrix_ca.dart';

void main() {
  // Harm: a developer with no rental history must not crash or lose their confirmed VPN on reload.
  test('a joined host VPN persists on a laptop without a prior host record', () async {
    final store = MemorySettingsStore();
    final settings = Settings(store);
    final reloaded = Settings(store);
    addTearDown(settings.dispose);
    addTearDown(reloaded.dispose);
    await settings.rememberJoinedHostVpn(
      host: PreparedHost.read(matrixHostValues()),
      account: 'dev',
      peerPublicKey: wireGuardKey,
      peerAddress: '10.73.7.10',
      ca: hostMatrixCa,
    );
    await reloaded.load();
    final record = reloaded.hostUp('orchard');
    expect(record, isNotNull);
    expect(record!.account, 'dev');
    expect(record.scalewayProject, isEmpty);
    expect(record.vpnPeerAddress, '10.73.7.10/32');
    expect(record.vpnHostPublicKey, wireGuardKey);
    expect(record.vpnEndpointAddress, '203.0.113.7');
    expect(record.forgeCa, hostMatrixCa);
  });

  // Harm: adding developer VPN state must not destroy existing server recovery information.
  test('remembering a joined VPN preserves an existing full host record', () async {
    final settings = Settings(MemorySettingsStore());
    addTearDown(settings.dispose);
    final existing = matrixHostRecord();
    await settings.rememberHostUp('orchard', existing);
    await settings.rememberJoinedHostVpn(
      host: PreparedHost.read(matrixHostValues()),
      account: 'dev',
      peerPublicKey: wireGuardKey,
      peerAddress: '10.73.7.10',
      ca: hostMatrixCa,
    );
    final kept = settings.hostUp('orchard')!;
    expect(kept.scalewayProject, existing.scalewayProject);
    expect(kept.account, existing.account);
    expect(kept.identity, existing.identity);
    expect(kept.publicKey, existing.publicKey);
    expect(kept.vpnPeerAddress, '10.73.7.10/32');
  });
}
