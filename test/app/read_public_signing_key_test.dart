import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/read_public_signing_key.dart';
import 'package:porelo_host/porelo_host.dart';

class _ReadingFile extends Fake implements File {
  _ReadingFile(this.file);
  final File file;
  var fullRead = false;
  final reads = <int>[];
  @override
  String get path => file.path;
  @override
  int lengthSync() => file.lengthSync();
  @override
  String readAsStringSync({Encoding encoding = utf8}) {
    fullRead = true;
    return file.readAsStringSync();
  }

  @override
  RandomAccessFile openSync({FileMode mode = FileMode.read}) => _Reader(file.openSync(mode: mode), reads);
}

class _Reader extends Fake implements RandomAccessFile {
  _Reader(this.file, this.reads);
  final RandomAccessFile file;
  final List<int> reads;
  @override
  Uint8List readSync(int bytes) {
    reads.add(bytes);
    return file.readSync(bytes);
  }

  @override
  void closeSync() => file.closeSync();
}

void main() {
  // Harm: selecting a private SSH key must not load its secret body while validating a public-key path.
  test('a private key is refused after its public armor prefix alone', () {
    final scratch = Directory.systemTemp.createTempSync('public-signing-key-');
    addTearDown(() => scratch.deleteSync(recursive: true));
    final file = _ReadingFile(
      File('${scratch.path}/selected')
        ..writeAsStringSync('-----BEGIN OPENSSH PRIVATE KEY-----\nprivate fixture body\n'),
    );
    expect(() => HostFiles.signingFingerprint(readPublicSigningKey(file)), throwsA(isA<HostFilesRefused>()));
    expect(file.fullRead, isFalse);
    expect(file.reads, [12]);
  });
}
