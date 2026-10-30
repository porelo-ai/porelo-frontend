import 'package:porelo_host/porelo_host.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'yaml_comments.dart';

/// One laptop's public identity in the signed access file.
class AccessLaptop {
  /// Checks both keys and strips the SSH comment before retaining them.
  AccessLaptop(String ssh, this.wireguardPublicKey, this.vpnAddress) : sshPublicKey = _sshKey(ssh) {
    checkWireGuardPublicKey(wireguardPublicKey);
  }

  /// The checked SSH public key without a comment.
  final String sshPublicKey;

  /// The checked WireGuard public key.
  final String wireguardPublicKey;

  /// The laptop’s address inside the host network.
  final String vpnAddress;

  /// The public fields accepted by the access-file schema.
  Map<String, String> toYaml() => {
    'ssh_public_key': sshPublicKey,
    'wireguard_public_key': wireguardPublicKey,
    'vpn_address': vpnAddress,
  };
}

/// A host account and the laptops allowed to use this project.
class AccessDeveloper {
  /// Retains only checked public values.
  AccessDeveloper(this.account, this.forgeLogin, List<AccessLaptop> laptops) : laptops = List.unmodifiable(laptops) {
    checkAdminName(account);
    if (forgeLogin != null) checkForgeLogin(forgeLogin!);
    if (laptops.isEmpty) throw const FormatException('Keep at least one laptop for a developer.');
  }

  /// The account name on the host.
  final String account;

  /// The optional central forge login.
  final String? forgeLogin;

  /// The immutable public identities of this developer’s laptops.
  final List<AccessLaptop> laptops;

  /// The mapping written under this account.
  Map<String, Object> toYaml() => {
    'forge_login': ?forgeLogin,
    'laptops': [for (final laptop in laptops) laptop.toYaml()],
  };
}

/// The checked host network and developer mapping, shared by settings and joining.
class AccessDevelopers {
  AccessDevelopers._(this.network, this.sshHostKey, this.developers, this._first, this._last);

  /// The CIDR network from the host block.
  final String network;

  /// The public SSH host key used for the admin sync.
  final String sshHostKey;

  /// The checked accounts keyed by their host names.
  final Map<String, AccessDeveloper> developers;
  final int _first;
  final int _last;

  /// The first usable address belongs to the host.
  String get hostAddress => _address(_first + 1);

  /// Checks subnet membership, host reservation, and every listed laptop's address.
  void checkAddress(String value) {
    final address = _ipv4(value);
    if (address <= _first + 1 || address >= _last) {
      throw FormatException('Choose a laptop VPN address in $network after the host address $hostAddress.');
    }
    if (developers.values.any((developer) => developer.laptops.any((laptop) => laptop.vpnAddress == value))) {
      throw const FormatException('This VPN address is already used by a listed laptop.');
    }
  }

  /// Proposes the lowest unused laptop address, skipping the host and broadcast.
  String nextAddress({Iterable<String> reserved = const []}) {
    final used = {
      ...reserved,
      for (final developer in developers.values)
        for (final laptop in developer.laptops) laptop.vpnAddress,
    };
    for (var address = _first + 2; address < _last; address++) {
      final candidate = _address(address);
      if (!used.contains(candidate)) return candidate;
    }
    throw const FormatException('The host network has no free laptop VPN address.');
  }
}

/// Parses the access file once for both developer settings and project joining.
///
/// Invalid input is refused without quoting any file contents.
AccessDevelopers parseAccessDevelopers(String source) {
  try {
    final root = loadYaml(source);
    if (root is! Map || root['host'] is! Map) throw const FormatException();
    final host = root['host'] as Map;
    final network = host['network'];
    final ssh = host['ssh_host_key'];
    if (network is! String || ssh is! String) throw const FormatException();
    final parts = network.split('/');
    if (parts.length != 2) throw const FormatException();
    final first = _ipv4(parts[0]);
    final prefix = int.tryParse(parts[1]);
    if (prefix == null || prefix < 0 || prefix > 30 || parts[1] != '$prefix') throw const FormatException();
    final size = 1 << (32 - prefix);
    if (first % size != 0) throw const FormatException();
    final listed = root['developers'];
    if (listed != null && listed is! Map) throw const FormatException();
    final developers = <String, AccessDeveloper>{};
    final result = AccessDevelopers._(network, _sshKey(ssh), developers, first, first + size - 1);
    final addresses = <String>{};
    for (final entry in (listed as Map? ?? {}).entries) {
      if (entry.key is! String || entry.value is! Map) throw const FormatException();
      final value = entry.value as Map;
      final login = value['forge_login'];
      final laptops = value['laptops'];
      if (login != null && login is! String || laptops is! List || laptops.isEmpty) throw const FormatException();
      final checked = <AccessLaptop>[];
      for (final laptop in laptops) {
        if (laptop is! Map ||
            laptop.keys.any((k) => !const {'ssh_public_key', 'wireguard_public_key', 'vpn_address'}.contains(k))) {
          throw const FormatException();
        }
        final ssh = laptop['ssh_public_key'], wg = laptop['wireguard_public_key'], address = laptop['vpn_address'];
        if (ssh is! String || wg is! String || address is! String) throw const FormatException();
        result.checkAddress(address);
        if (!addresses.add(address)) throw const FormatException();
        checked.add(AccessLaptop(ssh, wg, address));
      }
      developers[entry.key as String] = AccessDeveloper(entry.key as String, login as String?, checked);
    }
    return result;
  } on Exception {
    throw const FormatException(
      'access.yml needs a valid host network, SSH host key, and developers with public laptop keys and unique VPN addresses.',
    );
  }
}

/// Parses a pasted YAML public-key block and discards the SSH comment.
AccessLaptop parseLaptopPublicKeys(String block, String address) {
  try {
    final value = loadYaml(block);
    if (value is! Map ||
        value.length != 2 ||
        value['ssh_public_key'] is! String ||
        value['wireguard_public_key'] is! String) {
      throw const FormatException();
    }
    return AccessLaptop(value['ssh_public_key'] as String, value['wireguard_public_key'] as String, address);
  } on Exception {
    throw const FormatException(
      'Paste only ssh_public_key and wireguard_public_key from Copy my public keys. Private keys are refused.',
    );
  }
}

/// Checks a forge login before it becomes an API path component.
void checkForgeLogin(String login) {
  if (!RegExp(r'^[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?$').hasMatch(login) || login.contains('--')) {
    throw const FormatException(
      'Give the developer’s GitHub login, at most 39 letters, digits, and internal single dashes.',
    );
  }
}

/// Changes just one developer through yaml_edit, keeping unrelated settings and comments.
String writeAccessDeveloper(String source, String account, AccessDeveloper? developer) {
  checkAdminName(account);
  final parsed = parseAccessDevelopers(source);
  final editor = YamlEditor(source);
  if (developer == null) {
    if (!parsed.developers.containsKey(account)) throw const FormatException('This developer is no longer listed.');
    editor.remove(['developers', account]);
  } else {
    if (developer.account != account) throw const FormatException('The developer account differs.');
    if (editor.parseAt(['developers'], orElse: () => wrapAsYamlNode(null)).value == null) {
      editor.update(['developers'], <String, Object>{});
    }
    final previous = parsed.developers[account];
    if (previous == null) {
      editor.update(['developers', account], developer.toYaml());
    } else {
      if (previous.forgeLogin != developer.forgeLogin ||
          developer.laptops.any(
            (laptop) => !previous.laptops.any(
              (old) =>
                  old.vpnAddress == laptop.vpnAddress &&
                  old.sshPublicKey == laptop.sshPublicKey &&
                  old.wireguardPublicKey == laptop.wireguardPublicKey,
            ),
          )) {
        throw const FormatException('An existing developer edit may only remove laptops.');
      }
      for (var index = previous.laptops.length - 1; index >= 0; index--) {
        if (!developer.laptops.any((laptop) => laptop.vpnAddress == previous.laptops[index].vpnAddress)) {
          editor.remove(['developers', account, 'laptops', index]);
        }
      }
    }
  }
  final written = retainYamlComments(source, editor.toString());
  parseAccessDevelopers(written);
  return written;
}

String _sshKey(String key) {
  if (key.contains('\n') || key.contains('\r')) throw const FormatException('Give one SSH public key.');
  return checkedEd25519(key.trim().split(RegExp(r'\s+')).take(2).join(' '));
}

int _ipv4(String value) {
  final parts = value.split('.');
  if (parts.length != 4 || parts.any((p) => !RegExp(r'^(0|[1-9][0-9]{0,2})$').hasMatch(p) || int.parse(p) > 255)) {
    throw const FormatException('Give a canonical IPv4 address.');
  }
  return parts.map(int.parse).fold(0, (address, part) => (address << 8) | part);
}

String _address(int value) => [24, 16, 8, 0].map((shift) => (value >> shift) & 255).join('.');
