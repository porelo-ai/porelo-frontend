import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Checks the complete SSH public blob and returns its SHA256 fingerprint.
String sshSigningFingerprint(String publicKey) {
  final fields = publicKey.trim().split(RegExp(r'\s+'));
  if (fields.length < 2) throw const FormatException('Choose an ssh-ed25519 or ssh-rsa signing public key (.pub).');
  if (fields[0] != 'ssh-ed25519' && fields[0] != 'ssh-rsa') {
    throw const FormatException('Only ssh-ed25519 and ssh-rsa signing public keys are supported.');
  }
  try {
    final blob = base64Decode(fields[1]);
    final reader = _SshBlob(blob);
    if (utf8.decode(reader.field()) != fields[0]) throw const FormatException();
    if (fields[0] == 'ssh-ed25519') {
      if (reader.field().length != 32) throw const FormatException();
    } else {
      reader.positiveMpint();
      reader.positiveMpint();
    }
    if (!reader.atEnd) throw const FormatException();
    return 'SHA256:${base64Encode(sha256.convert(blob).bytes).replaceAll('=', '')}';
  } on FormatException {
    throw const FormatException('Choose a valid ssh-ed25519 or ssh-rsa signing public key (.pub).');
  }
}

/// OpenSSH fields carry their own lengths; no trailing byte belongs to a supported key.
class _SshBlob {
  _SshBlob(this.bytes);
  final List<int> bytes;
  int offset = 0;
  bool get atEnd => offset == bytes.length;

  List<int> field() {
    if (bytes.length - offset < 4) throw const FormatException();
    final size = (bytes[offset] << 24) | (bytes[offset + 1] << 16) | (bytes[offset + 2] << 8) | bytes[offset + 3];
    offset += 4;
    if (size > bytes.length - offset) throw const FormatException();
    final value = bytes.sublist(offset, offset + size);
    offset += size;
    return value;
  }

  void positiveMpint() {
    final value = field();
    if (value.isEmpty || value.first >= 128 || (value.first == 0 && (value.length == 1 || value[1] < 128))) {
      throw const FormatException();
    }
  }
}
