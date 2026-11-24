import 'dart:convert';

import 'package:crypto/crypto.dart' show sha256;

import 'host_record.dart' show checkedEd25519;

/// A host's identity carried into its setup: its SSH host keys, the organization's read key and each project's
/// repository key, as the person's Porelo-Vault kept them, read on `up --given --identity-stdin`'s standard input.
///
/// Checked here only so far as the setup needs before any connection: one object for the host set up, with one to
/// three host keys of which one is a valid ed25519 key, and no control character. Porelo checked the rest when it kept
/// it, and the host's own import checks it again. It never says its keys when printed.
final class CarriedIdentity {
  CarriedIdentity._(this.text, this.ed25519);

  /// The most an identity may be, as Porelo keeps it.
  static const most = 256 * 1024;

  /// The identity, exactly as it was read, for the host's setup.
  final String text;

  /// Its ed25519 host key, `ssh-ed25519 BASE64` with no comment: the key a host set up with it answers with.
  final String ed25519;

  /// The SHA-256 of [text], by which the host checks what arrived.
  String get digest => sha256.convert(utf8.encode(text)).toString();

  /// Reads at most [most] bytes from [input] and checks them for [host].
  static Future<CarriedIdentity> readFrom(Stream<List<int>> input, {required String host}) async {
    final bytes = <int>[];
    await for (final chunk in input) {
      bytes.addAll(chunk);
      if (bytes.length > most) throw const FormatException('The identity is larger than 256 KiB.');
    }
    return read(bytes, host: host);
  }

  /// Checks [bytes] as the identity of [host]. Its words never hold any part of the identity.
  static CarriedIdentity read(List<int> bytes, {required String host}) {
    if (bytes.length > most) throw const FormatException('The identity is larger than 256 KiB.');
    final String text;
    final Object? value;
    try {
      text = utf8.decode(bytes);
      value = jsonDecode(text);
    } on FormatException {
      throw const FormatException('The identity is not JSON.');
    }
    if (value is! Map<String, Object?>) throw const FormatException('The identity is not one JSON object.');
    if (value['host'] != host) throw FormatException('The identity is not the one of $host.');
    _plain(value, private: false);
    final keys = value['ssh_host_keys'];
    if (keys is! List || keys.isEmpty || keys.length > 3) {
      throw const FormatException('The identity needs one to three SSH host keys.');
    }
    final types = <String>{};
    String? ed25519;
    for (final key in keys) {
      final type = key is Map<String, Object?> ? key['type'] : null;
      if (type is! String || !const {'ed25519', 'ecdsa', 'rsa'}.contains(type) || !types.add(type)) {
        throw const FormatException('The identity holds an SSH host key of no known type, or one type twice.');
      }
      if (type == 'ed25519') {
        final public = (key as Map<String, Object?>)['public'];
        final parts = public is String ? public.split(' ') : const <String>[];
        try {
          ed25519 = checkedEd25519(parts.length < 2 ? '' : '${parts[0]} ${parts[1]}');
        } on FormatException {
          throw const FormatException("The identity's ed25519 host key is not a valid key.");
        }
      }
    }
    if (ed25519 == null) throw const FormatException('The identity holds no ed25519 host key.');
    return CarriedIdentity._(text, ed25519);
  }

  /// Refuses a control character in any text of [value], but the line breaks of a private key's PEM.
  static void _plain(Object? value, {required bool private}) {
    switch (value) {
      case String text:
        for (final unit in text.codeUnits) {
          if (private && unit == 0x0a) continue;
          if (unit < 0x20 || (unit >= 0x7f && unit < 0xa0)) {
            throw const FormatException('The identity holds a control character.');
          }
        }
      case Map<String, Object?> map:
        for (final MapEntry(:key, value: each) in map.entries) {
          _plain(key, private: false);
          _plain(each, private: key == 'private');
        }
      case List<Object?> list:
        for (final each in list) {
          _plain(each, private: false);
        }
      default:
    }
  }

  @override
  String toString() => 'CarriedIdentity($ed25519)';
}
