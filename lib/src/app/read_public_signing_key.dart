import 'dart:io';
import 'dart:convert';

import 'package:porelo_host/porelo_host.dart';

/// Reads the public signing key selected for project verification.
String readPublicSigningKey(File file) {
  const refused = HostFilesRefused('Choose a plain OpenSSH public signing key file, beginning with ssh-ed25519.');
  if (FileSystemEntity.typeSync(file.path, followLinks: false) != FileSystemEntityType.file ||
      file.lengthSync() > 8192) {
    throw refused;
  }
  final input = file.openSync();
  try {
    final prefix = input.readSync(12);
    if (ascii.decode(prefix, allowInvalid: true) != 'ssh-ed25519 ') throw refused;
    final text = utf8.decode([...prefix, ...input.readSync(8192)]);
    HostFiles.signingFingerprint(text);
    return text;
  } finally {
    input.closeSync();
  }
}
