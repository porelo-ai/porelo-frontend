import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:porelo_host/porelo_host.dart';

import 'host_matrix_settings.dart';
import 'host_vpn.dart';
import 'join_keys.dart';
import 'run_here.dart';

/// The join's public host and developer data from Porelo's verified access answer.
class AccessJoin {
  AccessJoin._(this.host, this.developers);

  /// Reads the access schema without depending on the admin's developer-list writer.
  factory AccessJoin.read(Object? answer) {
    if (answer is! Map) throw const WorkspaceRefused('Porelo did not answer with verified access settings.');
    final host = answer['host'];
    final transports = answer['transports'];
    final developers = answer['developers'];
    if (host is! Map || transports is! Map || developers is! Map) {
      throw const WorkspaceRefused('The verified access file needs host, developers, and transports mappings.');
    }
    final matrix = transports['matrix'];
    final url = matrix is Map && matrix['homeserver'] is String ? Uri.tryParse(matrix['homeserver'] as String) : null;
    if (url == null || url.scheme != 'https' || url.userInfo.isNotEmpty || url.hasQuery || url.hasFragment) {
      throw const WorkspaceRefused('The verified access file needs its host’s HTTPS Matrix homeserver.');
    }
    final PreparedHost prepared;
    try {
      prepared = PreparedHost.read({
        for (final field in host.entries) '${field.key}': field.value,
        'homeserver': url.host,
      });
    } on FormatException catch (error) {
      throw WorkspaceRefused(error.message);
    }
    final people = <String, List<({JoinPublicKeys keys, String address})>>{};
    final addresses = <String>{};
    final sshKeys = <String>{};
    final wireguardKeys = <String>{};
    for (final entry in developers.entries) {
      final account = entry.key;
      final value = entry.value;
      if (account is! String ||
          !RegExp(r'^[a-z_][a-z0-9_-]*$').hasMatch(account) ||
          account == 'root' ||
          value is! Map) {
        throw const WorkspaceRefused('The verified developer list has an invalid own-account name.');
      }
      final laptops = value['laptops'];
      if (laptops is! List || laptops.isEmpty) throw const WorkspaceRefused('Each developer needs a laptop list.');
      final checked = <({JoinPublicKeys keys, String address})>[];
      for (final laptop in laptops) {
        if (laptop is! Map ||
            laptop['ssh_public_key'] is! String ||
            laptop['wireguard_public_key'] is! String ||
            laptop['vpn_address'] is! String) {
          throw const WorkspaceRefused('Each laptop needs its SSH and WireGuard public keys and VPN address.');
        }
        final ssh = (laptop['ssh_public_key'] as String).trim().split(RegExp(r'\s+')).take(2).join(' ');
        final wireguard = laptop['wireguard_public_key'] as String;
        final address = laptop['vpn_address'] as String;
        try {
          checkedEd25519(ssh);
          checkWireGuardPublicKey(wireguard);
          checkJoinVpnAddress(address, prepared.network);
        } on FormatException catch (error) {
          throw WorkspaceRefused(error.message);
        }
        if (!addresses.add(address) || !sshKeys.add(ssh) || !wireguardKeys.add(wireguard)) {
          throw const WorkspaceRefused('Each laptop’s public keys and VPN address must be used once.');
        }
        checked.add((keys: (ssh: ssh, wireguard: wireguard), address: address));
      }
      people[account] = List.unmodifiable(checked);
    }
    return AccessJoin._(prepared, Map.unmodifiable(people));
  }

  /// The public values of this host, checked with the existing host reader.
  final PreparedHost host;

  /// The checked account and laptop entries, containing public values only.
  final Map<String, List<({JoinPublicKeys keys, String address})>> developers;

  /// The host's name, shared by its VPN and service names.
  String get hostName => host.values['homeserver']!.split('.')[1];

  /// Selects only this laptop's two matching keys; a dropped laptop has no repair action.
  ({String account, String address}) laptop(JoinPublicKeys keys) {
    for (final entry in developers.entries) {
      for (final laptop in entry.value) {
        if (laptop.keys == keys) return (account: entry.key, address: laptop.address);
      }
    }
    throw const WorkspaceRefused('The host refuses this laptop: the signed developer list does not admit it.');
  }
}

/// Refuses another network, the host's address, and unusable subnet addresses.
void checkJoinVpnAddress(String address, int network) {
  final match = RegExp('^10\\.73\\.$network\\.([1-9][0-9]{0,2})\$').firstMatch(address);
  if (match == null || int.parse(match[1]!) < 2 || int.parse(match[1]!) > 254) {
    throw const FormatException(
      'The laptop VPN address must be an unused address inside the host’s network, after its own address.',
    );
  }
}

/// Checks the fetched certificate before a root terminal can install trust or change the VPN.
void checkJoinCa(PreparedHost host, String pem) {
  if (!isForgeCaCertificate(pem)) throw const WorkspaceRefused('The fetched CA is not one PEM certificate.');
  final der = base64Decode(pem.split('\n').where((line) => !line.startsWith('-----')).join());
  final actual = sha256.convert(der).toString();
  final expected = host.values['ca_sha256'];
  if (actual != expected) {
    throw WorkspaceRefused('The host CA was refused.\nExpected SHA-256: $expected\nReceived SHA-256: $actual');
  }
  checkHostMatrixCa(host, pem);
}
