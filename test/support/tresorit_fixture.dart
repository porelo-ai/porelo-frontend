import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

/// Installers laid out as Tresorit's, signed by CAs made for a test with this computer's `openssl`, in [scratch].
class TresoritFixture {
  /// Works in [scratch].
  TresoritFixture(this.scratch);

  /// Where the keys and certificates are made.
  final Directory scratch;

  /// Whether this computer can make them.
  static String? get skip => File('/usr/bin/openssl').existsSync() ? null : 'needs /usr/bin/openssl';

  Future<void> openssl(List<String> arguments) async {
    final result = await Process.run('/usr/bin/openssl', arguments, workingDirectory: scratch.path);
    expect(result.exitCode, 0, reason: '${arguments.first}: ${result.stderr}');
  }

  /// A CA as Tresorit's Code Signing CA, and a certificate it issues, with [usage], valid twenty days.
  Future<({String ca, String signing})> certificates(String name, {String usage = 'codeSigning'}) async {
    await openssl([
      'req',
      '-x509',
      '-newkey',
      'rsa:2048',
      '-nodes',
      '-keyout',
      '$name-ca.key',
      '-out',
      '$name-ca.pem',
      '-days',
      '30',
      '-subj',
      '/CN=$name CA',
      '-addext',
      'basicConstraints=critical,CA:TRUE,pathlen:0',
      '-addext',
      'keyUsage=critical,keyCertSign,cRLSign',
    ]);
    await openssl([
      'req',
      '-newkey',
      'rsa:2048',
      '-nodes',
      '-keyout',
      '$name.key',
      '-out',
      '$name.csr',
      '-subj',
      '/CN=$name Code Signing',
    ]);
    await File(path.join(scratch.path, '$name.ext'))
        .writeAsString('basicConstraints=critical,CA:FALSE\nextendedKeyUsage=critical,$usage\n');
    await openssl([
      'x509',
      '-req',
      '-in',
      '$name.csr',
      '-CA',
      '$name-ca.pem',
      '-CAkey',
      '$name-ca.key',
      '-CAcreateserial',
      '-out',
      '$name.pem',
      '-days',
      '20',
      '-extfile',
      '$name.ext',
    ]);
    return (
      ca: await File(path.join(scratch.path, '$name-ca.pem')).readAsString(),
      signing: await File(path.join(scratch.path, '$name.pem')).readAsString(),
    );
  }

  String fingerprint(String pem) =>
      sha256.convert(base64.decode(pem.split('\n').where((line) => !line.startsWith('-----')).join())).toString();

  /// An installer as Tresorit lays it out, signed by [key]'s key over everything from line 3 on, which installs by
  /// writing a marker into the folder it is given.
  Future<Uint8List> installer(String key, List<String> chain) async {
    final signed = utf8.encode(
      'CERT_CHAIN="${chain.join().replaceAll('\n', r'\n')}"\n'
      'if [ "\$1" = --update-v2 ]; then mkdir -p "\$2" && echo installed > "\$2/marker"; fi\n',
    );
    await File(path.join(scratch.path, 'signed')).writeAsBytes(signed);
    await openssl([
      'dgst',
      '-sha512',
      '-sigopt',
      'rsa_padding_mode:pss',
      '-sigopt',
      'rsa_pss_saltlen:digest',
      '-sigopt',
      'rsa_mgf1_md:sha512',
      '-sign',
      '$key.key',
      '-out',
      'signature',
      'signed',
    ]);
    final signature = await File(path.join(scratch.path, 'signature')).readAsBytes();
    final hex = [for (final byte in signature) byte.toRadixString(16).padLeft(2, '0')].join();
    return Uint8List.fromList([...utf8.encode('#!/bin/sh\nSIGNATURE=$hex\n'), ...signed]);
  }
}
