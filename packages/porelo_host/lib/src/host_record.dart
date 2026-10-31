import 'dart:convert';

import 'ssh_public_key.dart';

/// Checks a server's single DNS label before it names a rental or an inventory.
void checkHostName(String name) {
  if (!RegExp(r'^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$').hasMatch(name)) {
    throw const FormatException(
      'The server name needs one DNS label: lower-case letters, digits and internal dashes, at most 63 characters.',
    );
  }
}

/// Whether a value is a canonical dotted-decimal IPv4 address.
bool isIpv4Address(String value) {
  final parts = value.split('.');
  return parts.length == 4 &&
      parts.every((part) => RegExp(r'^(0|[1-9][0-9]{0,2})$').hasMatch(part) && int.parse(part) <= 255);
}

/// Whether a host card's address is one Core's card takes, read without a resolver: a plain IPv4 address, an IPv6
/// address in hex and colons alone, or a host name whose last label is no number.
bool isCardAddress(String value) {
  if (value.length > 253) return false;
  if (RegExp(r'^[0-9.]+$').hasMatch(value)) return isIpv4Address(value);
  if (value.contains(':')) return RegExp(r'^[0-9A-Fa-f:]+$').hasMatch(value) && _ipv6(value);
  final last = value.substring(value.lastIndexOf('.') + 1);
  return RegExp(r'^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*$')
          .hasMatch(value) &&
      !RegExp(r'^[0-9]+$').hasMatch(last) &&
      !RegExp(r'^0[xX][0-9A-Fa-f]*$').hasMatch(last);
}

/// Whether hex-and-colon [value] is one IPv6 address: eight groups, or fewer around one `::`.
bool _ipv6(String value) {
  final halves = value.split('::');
  if (halves.length > 2) return false;
  List<String> groups(String half) => half.isEmpty ? const [] : half.split(':');
  final all = [for (final half in halves) ...groups(half)];
  if (all.any((group) => group.isEmpty || group.length > 4)) return false;
  return halves.length == 2 ? all.length < 8 : all.length == 8;
}

bool _usableIpv4(String value) {
  if (!isIpv4Address(value)) return false;
  final parts = value.split('.').map(int.parse).toList();
  return value != '0.0.0.0' && parts[0] != 127 && !(parts[0] >= 224 && parts[0] <= 239);
}

/// Refuses a public key with a comment, a wrong type, or a malformed SSH blob.
String checkedEd25519(String value) {
  if (!RegExp(r'^ssh-ed25519 [A-Za-z0-9+/]+={0,2}$').hasMatch(value)) {
    throw const FormatException('Give one ssh-ed25519 public key with no comment.');
  }
  try {
    sshSigningFingerprint(value);
    final encoded = value.split(' ')[1];
    if (base64Encode(base64Decode(encoded)) != encoded) {
      throw const FormatException('Give a valid ssh-ed25519 public key.');
    }
  } on FormatException {
    throw const FormatException('Give a valid ssh-ed25519 public key.');
  }
  return value;
}

/// The checked SSH completion of a server, before Core signs its host card.
class PreparedHost {
  PreparedHost._(this.name, this.address, this.sshPort, this.sshHostKey, this.services);

  /// Reads a saved card, or completes Machines' result using preparation choices.
  ///
  /// [hostName] supplies the name missing from host.json. [localServices] supplies
  /// the person's forward ends, independently of the host's service ports.
  factory PreparedHost.read(Object? json, {String? hostName, Map<String, Map<String, int>>? localServices}) {
    if (json is! Map<String, Object?>) throw const FormatException('The host completion needs an object.');
    final name = json['name'] ?? hostName;
    final address = json['address'];
    final port = hostName == null ? json['ssh_port'] : 22;
    final key = json['ssh_host_key'];
    final remoteServices = json['services'];
    if (name is! String) throw const FormatException('The host completion needs its name.');
    checkHostName(name);
    if (hostName != null && name != hostName) throw const FormatException('The completion names another server.');
    if (address is! String || !_usableIpv4(address)) {
      throw const FormatException('The host completion needs a usable IPv4 address.');
    }
    if (port is! int || port < 1 || port > 65535 || key is! String) {
      throw const FormatException('The host completion needs valid ssh_port and ssh_host_key.');
    }
    checkedEd25519(key);
    if (hostName != null) {
      final forge = remoteServices is Map ? remoteServices['forge'] : null;
      if (forge is! Map || [forge['web_port'], forge['git_port']].any((p) => p is! int || p < 1 || p > 65535)) {
        throw const FormatException('The host completion needs valid forge service ports.');
      }
    }
    final services = hostName == null ? remoteServices : localServices ?? defaultLocalServices;
    if (services is! Map<String, Object?>) {
      throw const FormatException('The host completion needs services with port numbers.');
    }
    final forge = services['forge'];
    final matrix = services['matrix'];
    if (forge is! Map<String, Object?> || matrix is! Map<String, Object?>) {
      throw const FormatException('The host completion needs forge and matrix service ports.');
    }
    final ports = [forge['web_port'], forge['git_port'], matrix['port']];
    if (ports.any((p) => p is! int || p < 1 || p > 65535) || ports.toSet().length != ports.length) {
      throw const FormatException('The host completion needs three distinct valid service ports.');
    }
    return PreparedHost._(
      name,
      address,
      port,
      key,
      Map.unmodifiable({
        'forge': Map<String, int>.unmodifiable({'web_port': ports[0] as int, 'git_port': ports[1] as int}),
        'matrix': Map<String, int>.unmodifiable({'port': ports[2] as int}),
      }),
    );
  }

  /// Reads a host card as Core's registry answers it: `host`, `address`, `ssh_port`, `ssh_host_key`, `services` and
  /// `signed_by`, with the address in any form Core's card takes (a host name, an IPv4 or an IPv6 address).
  factory PreparedHost.card(Object? json) {
    if (json is! Map<String, Object?>) throw const FormatException('The host card needs an object.');
    final name = json['host'];
    final address = json['address'];
    final port = json['ssh_port'];
    final key = json['ssh_host_key'];
    if (name is! String) throw const FormatException('The host card needs its host.');
    checkHostName(name);
    if (address is! String || !isCardAddress(address)) {
      throw const FormatException('The host card needs a host name or an IP address.');
    }
    if (port is! int || port < 1 || port > 65535 || key is! String) {
      throw const FormatException('The host card needs valid ssh_port and ssh_host_key.');
    }
    checkedEd25519(key);
    final services = json['services'];
    final forge = services is Map<String, Object?> ? services['forge'] : null;
    final matrix = services is Map<String, Object?> ? services['matrix'] : null;
    if (forge is! Map<String, Object?> || matrix is! Map<String, Object?>) {
      throw const FormatException('The host card needs forge and matrix service ports.');
    }
    final ports = [forge['web_port'], forge['git_port'], matrix['port']];
    if (ports.any((p) => p is! int || p < 1 || p > 65535) || ports.toSet().length != ports.length) {
      throw const FormatException('The host card needs three distinct valid service ports.');
    }
    return PreparedHost._(
      name,
      address,
      port,
      key,
      Map.unmodifiable({
        'forge': Map<String, int>.unmodifiable({'web_port': ports[0] as int, 'git_port': ports[1] as int}),
        'matrix': Map<String, int>.unmodifiable({'port': ports[2] as int}),
      }),
    );
  }

  /// The server's DNS label.
  final String name;

  /// The server's SSH address, including private rental networks.
  final String address;

  /// The SSH port in the signed host card.
  final int sshPort;

  /// The server's pinned SSH public key.
  final String sshHostKey;

  /// The fixed local service ports, grouped as in the signed host card.
  final Map<String, Map<String, int>> services;

  /// The person's default local ends of the SSH forwards.
  static const defaultLocalServices = {
    'forge': {'web_port': 3000, 'git_port': 3001},
    'matrix': {'port': 8448},
  };

  /// The public completion shape supplied to Core for signing.
  Map<String, Object> get values => {
    'name': name,
    'address': address,
    'ssh_port': sshPort,
    'ssh_host_key': sshHostKey,
    'services': services,
  };

  /// The same checked completion shape retained for publication and retry.
  Map<String, Object> get stored => values;

  /// The SSH key fingerprint, including the complete public blob.
  String get fingerprint => sshSigningFingerprint(sshHostKey);
}
