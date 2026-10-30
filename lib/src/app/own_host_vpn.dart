import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:porelo_host/porelo_host.dart';

import 'access_checkout.dart';
import 'access_join.dart';
import 'join_keys.dart';
import 'run_here.dart';
import 'settings.dart';

/// Connects with public laptop values; a null CA permits only the VPN connection.
typedef ActivateOwnHostVpn = Future<bool> Function(PreparedHost host, JoinPublicKeys keys, String address, String? ca);

/// Shares the join's verified VPN and host recording with a first bring.
Future<String> connectOwnHostVpn({
  required PreparedHost host,
  required String account,
  required JoinPublicKeys keys,
  required String address,
  required Settings settings,
  required ActivateOwnHostVpn activate,
  String? ca,
  Future<String> Function()? fetchCa,
}) async {
  checkAdminName(account);
  if (account == 'root') throw const WorkspaceRefused('Use your admitted own account for this host.');
  checkJoinVpnAddress(address, host.network);
  if (ca == null) {
    if (fetchCa == null) throw const WorkspaceRefused('The host CA cannot be fetched.');
    if (!await activate(host, keys, address, null)) {
      throw const WorkspaceRefused('The VPN check did not confirm this host. The bring did not start.');
    }
    ca = await fetchCa();
  }
  checkJoinCa(host, ca);
  if (!await activate(host, keys, address, ca)) {
    throw const WorkspaceRefused('The VPN and CA check did not confirm this host. Nothing was brought or joined.');
  }
  await settings.rememberJoinedHostVpn(
    host: host,
    account: account,
    peerPublicKey: keys.wireguard,
    peerAddress: address,
    ca: ca,
  );
  return ca;
}

/// Refuses the host admin's address as well as addresses outside this host's VPN.
void checkBringVpnAddress(String address, int network) {
  checkJoinVpnAddress(address, network);
  if (address == '10.73.$network.2') {
    throw const FormatException('Use this machine’s VPN address, after the host admin’s .2 address.');
  }
}

/// Pins only this host's advertised SSH key, without accepting links or other hosts.
Future<void> pinOwnHostKey(String file, PreparedHost host) async {
  final name = host.values['homeserver']!.split('.')[1];
  if (!path.isAbsolute(file) || !file.endsWith('.$name')) {
    throw const WorkspaceRefused('Use this host’s own pinned known_hosts file.');
  }
  final destination = File(file);
  await privateDirectory(destination.parent);
  final type = await FileSystemEntity.type(file, followLinks: false);
  if (type != FileSystemEntityType.file && type != FileSystemEntityType.notFound) {
    throw const WorkspaceRefused('The host’s known_hosts must be a plain file, without links.');
  }
  final staging = await HostFileWriter().createPrivateTemporary(destination.parent);
  try {
    final prepared = File(path.join(staging.path, 'known_hosts'));
    final key = host.values['ssh_host_key']!.split(' ').take(2).join(' ');
    final contents = '${host.vpnAddress} $key\n';
    await HostFileWriter().write(prepared, utf8.encode(contents));
    await prepared.rename(file);
    if (await destination.readAsString() != contents) {
      throw const WorkspaceRefused('The host’s pinned SSH key was not kept.');
    }
  } finally {
    await staging.delete(recursive: true);
  }
}

/// Reads only the public CA through the pinned own-account VPN connection.
Future<String> fetchOwnHostCa({
  required PreparedHost host,
  required String account,
  required String knownHosts,
  required Remote remote,
}) async {
  await pinOwnHostKey(knownHosts, host);
  final lines = <String>[];
  final result = await remote.run(
    host.vpnAddress,
    account,
    '/usr/bin/cat /etc/porelo-host/forge/ca.pem',
    onLine: lines.add,
  );
  if (result.exitCode != 0) throw const WorkspaceRefused('The host CA could not be fetched through the VPN.');
  return '${lines.join('\n')}\n';
}
