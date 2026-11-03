import 'dart:convert';

import 'package:crypto/crypto.dart' show Hmac, sha1;

import 'organization_source.dart';

/// A step of preparing a host refused here, in words safe to show.
class HostAccessRefused implements Exception {
  /// Keeps why.
  const HostAccessRefused(this.words);

  /// Why, in a sentence.
  final String words;

  @override
  String toString() => words;
}

/// The pin a first `up` starts from: one `login key` line per row of the host's admins, backup keys among them.
///
/// A short pin leaves out someone the host should trust, and a wrong one trusts someone else, so a row whose login or
/// key cannot go on one line refuses the whole pin instead of being passed over.
String hostPin(OrganizationHost host) {
  if (host.adminKeys.isEmpty) {
    throw HostAccessRefused(
      'The organization names no Machine Admin key for ${host.name}, so no machine can be pinned.',
    );
  }
  final lines = <String>[];
  for (final row in host.adminKeys) {
    final key = row.key;
    if (key == null || !_key.hasMatch(key) || !_login.hasMatch(row.login)) {
      throw HostAccessRefused(
        "The organization's answer gives no usable key for ${_login.hasMatch(row.login) ? row.login : 'a Machine Admin'} "
        'of ${host.name}, so no machine can be pinned.',
      );
    }
    lines.add('${row.login} $key');
  }
  return '${lines.join('\n')}\n';
}

final _key = RegExp(r'^[a-z0-9-]+ [A-Za-z0-9+/]+={0,2}$');
final _login = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$');

/// How `known_hosts` names the forge [forge] of [address]: ssh writes a port other than its own with the name, in brackets.
String forgeInKnownHosts(String forge, String? address) {
  final uri = Uri.tryParse(address ?? '');
  if (uri == null || !const {'ssh', 'git+ssh'}.contains(uri.scheme) || !uri.hasPort || uri.port == 22) return forge;
  // An IPv6 literal comes in its brackets already.
  return '${forge.startsWith('[') ? forge : '[$forge]'}:${uri.port}';
}

/// The lines of the person's own `known_hosts` that pin [forge], as `forge type key`, for the host's `--known-hosts`.
///
/// Only what this person's ssh already trusts goes on, since first use is not trusted: nothing is asked of the forge.
/// A wildcard pattern pins no forge by name and a certificate authority no key of it, so neither counts; a revoked key
/// of that forge refuses them all.
String centralForgeKnownHosts(String forge, String knownHosts) {
  final name = forge.toLowerCase();
  final lines = <String>{};
  for (final raw in const LineSplitter().convert(knownHosts)) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final fields = line.split(RegExp(r'\s+'));
    final marker = fields.first.startsWith('@') ? fields.removeAt(0) : null;
    if (fields.length < 3 || !_applies(fields.first, name)) continue;
    if (marker == '@revoked') {
      throw HostAccessRefused(
        "A key of $forge is marked revoked in your known_hosts, so its keys are not handed to a machine. Sort that out "
        'with ssh-keygen -R and connect to it once yourself.',
      );
    }
    if (marker == null && _namesItself(fields.first, name)) lines.add('$name ${fields[1]} ${fields[2]}');
  }
  if (lines.isEmpty) {
    throw HostAccessRefused(
      'Your known_hosts holds no key of $forge, so a machine could not trust that forge: first use is not trusted. '
      'Connect to $forge once with ssh yourself, check its key, and try again.',
    );
  }
  return '${lines.join('\n')}\n';
}

/// Whether ssh would apply a line of [patterns] to [name]: one pattern matches and no negated one does.
bool _applies(String patterns, String name) {
  if (patterns.startsWith('|1|')) return _hashedName(patterns, name);
  var applies = false;
  for (final pattern in patterns.toLowerCase().split(',')) {
    final negated = pattern.startsWith('!');
    if (!_glob(negated ? pattern.substring(1) : pattern).hasMatch(name)) continue;
    if (negated) return false;
    applies = true;
  }
  return applies;
}

/// Whether [patterns] spell out [name], as a wildcard, which pins no forge by name, does not.
bool _namesItself(String patterns, String name) =>
    patterns.startsWith('|1|') || patterns.toLowerCase().split(',').contains(name);

RegExp _glob(String pattern) => RegExp('^${RegExp.escape(pattern).replaceAll(r'\*', '.*').replaceAll(r'\?', '.')}\$');

bool _hashedName(String hashed, String name) {
  final parts = hashed.split('|');
  if (parts.length != 4) return false;
  try {
    final digest = Hmac(sha1, base64Decode(parts[2])).convert(utf8.encode(name));
    return base64Encode(digest.bytes) == parts[3];
  } on FormatException {
    return false;
  }
}

/// The machine file's `organization` part, in the keys `up` reads; JSON strings are YAML scalars, so no value can break
/// out of its line.
String hostMachineFile({required String settings, required String knownHosts, required String pin}) => [
  'organization:',
  '  settings: ${jsonEncode(settings)}',
  '  known_hosts: ${jsonEncode(knownHosts)}',
  '  pin: ${jsonEncode(pin)}',
  '',
].join('\n');
