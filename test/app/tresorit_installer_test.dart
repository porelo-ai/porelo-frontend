import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:porelo_frontend/src/app/tresorit_installer.dart';

import '../support/tresorit_fixture.dart';

/// Tresorit's installer, checked against its own signature under the pinned CA before any byte of it runs: on
/// installers laid out as Tresorit's, signed by a CA made for the test with this computer's `openssl`.
void main() {
  final skip = TresoritFixture.skip;
  late Directory scratch;

  setUp(() async => scratch = await Directory.systemTemp.createTemp('tresorit-installer-'));
  tearDown(() => scratch.delete(recursive: true));

  late TresoritFixture fixture;
  setUp(() => fixture = TresoritFixture(scratch));
  Future<({String ca, String signing})> certificates(String name, {String usage = 'codeSigning'}) =>
      fixture.certificates(name, usage: usage);
  String fingerprint(String pem) => fixture.fingerprint(pem);
  Future<Uint8List> installer(String key, List<String> chain) => fixture.installer(key, chain);

  /// Puts what the machine is sent into a folder and runs its script there, as the machine would: true when the
  /// installer ran.
  Future<({bool installed, String said})> check(TresoritInstaller read) async {
    final folder = await Directory(path.join(scratch.path, 'sent')).create();
    await File(path.join(folder.path, 'installer.run')).writeAsBytes(read.bytes);
    await File(path.join(folder.path, 'signature.bin')).writeAsBytes(read.signature);
    await File(path.join(folder.path, 'signing.pem')).writeAsString(read.signing);
    await File(path.join(folder.path, 'ca.pem')).writeAsString(read.ca);
    final client = path.join(scratch.path, 'client');
    final result = await Process.run('/bin/bash', [
      '-c',
      TresoritInstaller.checkScript(folder.path, clientDir: client),
    ]);
    expect(await folder.exists(), isFalse, reason: 'what was sent goes, whatever came of it');
    return (installed: File(path.join(client, 'marker')).existsSync(), said: '${result.stdout}${result.stderr}');
  }

  // Harm: an installer that is not Tresorit's runs as the user, or one that is runs without its check.
  test('an installer signed under the pinned CA runs, as it is, and only then', () async {
    final good = await certificates('tresorit');
    final read = TresoritInstaller.read(
      await installer('tresorit', [good.signing, good.ca]),
      pinned: fingerprint(good.ca),
    );
    expect(fingerprint(read.ca), fingerprint(good.ca), reason: 'exactly the CA with the pin');
    expect(fingerprint(read.signing), fingerprint(good.signing), reason: 'and the chain\'s first, the signer');
    final ran = await check(read);
    expect(ran.installed, isTrue, reason: ran.said);
  }, skip: skip);

  test('the chain without the pinned CA is refused before anything is sent', () async {
    final good = await certificates('tresorit');
    final other = await certificates('other');
    expect(
      () async =>
          TresoritInstaller.read(await installer('tresorit', [good.signing, good.ca]), pinned: fingerprint(other.ca)),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('pinned fingerprint'))),
    );
    for (final broken in [
      '#!/bin/sh\n',
      '#!/bin/sh\nSIGNATURE=zz\nCERT_CHAIN=""\n',
      '#!/bin/sh\nSIGNATURE=00\nNOT_A_CHAIN\n',
    ]) {
      expect(() => TresoritInstaller.read(Uint8List.fromList(utf8.encode(broken))), throwsFormatException);
    }
  }, skip: skip);

  test(
    'a byte changed after signing, a certificate the pinned CA did not issue, or one not for code signing never runs',
    () async {
      final good = await certificates('tresorit');
      final pin = fingerprint(good.ca);

      final bytes = await installer('tresorit', [good.signing, good.ca]);
      // A change that leaves it a script that runs: only the signature can tell.
      final at = utf8.decode(bytes, allowMalformed: true).lastIndexOf('installed');
      bytes[at] = 'X'.codeUnitAt(0);
      expect((await check(TresoritInstaller.read(bytes, pinned: pin))).installed, isFalse, reason: 'changed after');

      final other = await certificates('other');
      // Signed by another CA's certificate, with the pinned CA carried beside it.
      final foreign = TresoritInstaller.read(await installer('other', [other.signing, good.ca]), pinned: pin);
      expect((await check(foreign)).installed, isFalse, reason: 'not issued by the pinned CA');

      final mail = await certificates('mail', usage: 'emailProtection');
      final notForCode = TresoritInstaller.read(
        await installer('mail', [mail.signing, mail.ca]),
        pinned: fingerprint(mail.ca),
      );
      expect((await check(notForCode)).installed, isFalse, reason: 'not made for code signing');
    },
    skip: skip,
  );
}
