import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:porelo_host/porelo_host.dart';

import 'host_vpn.dart' show isForgeCaCertificate;
import 'run_here.dart';

/// The room alias accepted by the host's room creation task.
String hostProjectRoom(String project, PreparedHost host) => '#porelo-$project:${host.values['homeserver']}';

/// Checks the host's retained public CA before any private access edit or upload.
void checkHostMatrixCa(PreparedHost host, String? pem) {
  if (pem == null || pem.isEmpty) {
    throw const WorkspaceRefused(
      'The trusted CA certificate for this host is missing. Keep this host’s forge CA before bringing the project.',
    );
  }
  if (!isForgeCaCertificate(pem)) {
    throw const WorkspaceRefused('The host’s trusted CA must be one PEM certificate, with no chain or other text.');
  }
  final der = base64Decode(pem.split('\n').where((line) => !line.startsWith('-----')).join());
  try {
    if (!_oneDerObject(der)) throw const FormatException();
    SecurityContext(withTrustedRoots: false).setTrustedCertificatesBytes(utf8.encode(pem));
  } on Exception {
    throw const WorkspaceRefused('The host’s trusted CA must contain one valid certificate.');
  }
  if (sha256.convert(der).toString() != host.values['ca_sha256']) {
    throw const WorkspaceRefused(
      'The trusted CA certificate for this host does not match its ca_sha256. No access settings were changed.',
    );
  }
}

bool _oneDerObject(List<int> der) {
  if (der.length < 2 || der[0] != 0x30) return false;
  var length = der[1];
  var start = 2;
  if (length >= 0x80) {
    final count = length & 0x7f;
    if (count == 0 || count > 4 || start + count > der.length || der[start] == 0) return false;
    length = 0;
    for (var index = 0; index < count; index++) {
      length = (length << 8) | der[start++];
    }
    if (length < 0x80) return false;
  }
  return start + length == der.length;
}
