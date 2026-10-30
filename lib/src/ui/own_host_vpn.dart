import 'package:flutter/material.dart';
import 'package:porelo_host/porelo_host.dart';

import '../app/host_vpn.dart';
import '../app/join_keys.dart';
import '../app/machines.dart';
import '../app/session.dart';
import '../app/settings.dart';
import 'unlock_terminal.dart';

/// Opens the shared local VPN terminal and verifies its fresh host handshake.
Future<bool> openOwnHostVpn(
  BuildContext context, {
  required PreparedHost host,
  required JoinPublicKeys keys,
  required String address,
  required String? ca,
  required Settings settings,
  required SecretStore store,
  Map<String, String>? environment,
  OpenTerminal? openTerminal,
}) async {
  final name = host.values['homeserver']!.split('.')[1];
  await checkHostVpnNetwork(
    host: name,
    networkNumber: host.network,
    hostsByInterface: {for (final entry in settings.hostUps.entries) entry.value.vpnInterface: entry.key},
  );
  final attempt = await prepareHostVpn(
    project: name,
    tunnel: HostTunnel(hostPublicKey: host.values['wireguard_public_key']!, peerPublicKey: keys.wireguard),
    address: host.values['address']!,
    peerAddress: address,
    networkNumber: host.network,
    forgeCa: ca,
    secretStore: store,
    environment: environment,
  );
  var verified = false;
  try {
    if (!context.mounted) return false;
    await runInATerminal(
      context,
      title: ca == null ? 'Connect this laptop to $name' : 'Connect and trust $name',
      explanation: ca == null
          ? 'Type your sudo password here to connect with this laptop’s VPN address. The host CA will be fetched through pinned SSH and checked before it is trusted.'
          : 'The host CA matches its SHA-256. Type your sudo password here to install this host’s VPN and verified CA on this computer.',
      machine: Machine.local(),
      command: attempt.command,
      open: openTerminal,
      shownCommand: ca == null
          ? 'Connect with your laptop address, without installing a CA.'
          : 'Connect with your laptop address and trust the verified host CA.',
      finish: (code) async {
        verified = code == 0 && await attempt.verified();
        return verified;
      },
      afterClose: attempt.close,
    );
    return verified;
  } finally {
    await attempt.close();
  }
}
