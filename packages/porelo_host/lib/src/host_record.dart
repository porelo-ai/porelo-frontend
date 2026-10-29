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

/// Checks the server's subnet number before it reaches an inventory.
void checkHostNetwork(int network) {
  if (network < 0 || network > 255) throw const FormatException('The network number needs an integer from 0 to 255.');
}

/// Whether a value is a canonical dotted-decimal IPv4 address.
bool isIpv4Address(String value) {
  final parts = value.split('.');
  return parts.length == 4 &&
      parts.every((part) => RegExp(r'^(0|[1-9][0-9]{0,2})$').hasMatch(part) && int.parse(part) <= 255);
}

bool _publicIpv4(String value) {
  if (!isIpv4Address(value)) return false;
  final parts = value.split('.').map(int.parse).toList();
  return parts[0] > 0 &&
      parts[0] < 224 &&
      parts[0] != 10 &&
      parts[0] != 127 &&
      !(parts[0] == 169 && parts[1] == 254) &&
      !(parts[0] == 172 && parts[1] >= 16 && parts[1] <= 31) &&
      !(parts[0] == 192 && parts[1] == 168) &&
      !(parts[0] == 100 && parts[1] >= 64 && parts[1] <= 127);
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

/// Refuses a WireGuard key that is not 32 bytes in canonical base64.
void checkWireGuardPublicKey(String value) {
  if (!RegExp(r'^[A-Za-z0-9+/]{43}=$').hasMatch(value)) {
    throw const FormatException('Give a WireGuard public key as 44 base64 characters ending in =.');
  }
  try {
    final bytes = base64Decode(value);
    if (bytes.length != 32 || base64Encode(bytes) != value) throw const FormatException();
  } on FormatException {
    throw const FormatException('Give a valid WireGuard public key.');
  }
}

/// The checked public values a prepared server gives its project admins.
class PreparedHost {
  PreparedHost._(this.values);

  /// Reads all seven fields, naming the missing or malformed field in a refusal.
  factory PreparedHost.read(Object? json) {
    if (json is! Map<String, Object?>) throw const FormatException('host.json needs an object.');
    final values = <String, String>{};
    for (final name in const [
      'address',
      'endpoint',
      'wireguard_public_key',
      'network',
      'ssh_host_key',
      'ca_sha256',
      'homeserver',
    ]) {
      final value = json[name];
      if (value is! String || value.isEmpty) throw FormatException('host.json: $name is missing or malformed.');
      values[name] = value;
      var valid = true;
      try {
        valid = switch (name) {
          'address' => _publicIpv4(value),
          'endpoint' => value == '${values['address']}:51820',
          'network' =>
            RegExp(r'^10\.73\.(0|[1-9][0-9]{0,2})\.0/24$').hasMatch(value) && int.parse(value.split('.')[2]) <= 255,
          'ca_sha256' => RegExp(r'^[0-9a-f]{64}$').hasMatch(value),
          'homeserver' => RegExp(r'^matrix\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.porelo\.internal$').hasMatch(value),
          _ => true,
        };
        if (name == 'wireguard_public_key') checkWireGuardPublicKey(value);
        if (name == 'ssh_host_key') {
          final match = RegExp(r'^ssh-ed25519 ([A-Za-z0-9+/]+={0,2})(?: [^\x00-\x1f\x7f]+)?$').firstMatch(value);
          if (match == null) throw const FormatException();
          checkedEd25519('ssh-ed25519 ${match.group(1)}');
        }
      } on FormatException {
        valid = false;
      }
      if (!valid) throw FormatException('host.json: $name is malformed.');
    }
    return PreparedHost._(Map.unmodifiable(values));
  }

  /// Validated public values, safe to persist or copy individually.
  final Map<String, String> values;

  /// OpenSSH's SHA256 fingerprint computed from the complete SSH public blob.
  String get fingerprint => sshSigningFingerprint(values['ssh_host_key']!);

  /// The subnet's number.
  int get network => int.parse(values['network']!.split('.')[2]);
}
