// Linux only: it runs tool/third_party_notices.dart as tool/package.sh does, on Linux.
@Tags(<String>['linux'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// Holds the .deb and .rpm to carrying the licenses of the third-party code built into the window as one plain file.
void main() {
  late Directory scratch;

  setUp(() => scratch = Directory.systemTemp.createTempSync('notices-'));
  tearDown(() => scratch.deleteSync(recursive: true));

  // As Flutter writes it: each package's names, a blank line, its full license, and a line of dashes between them.
  const notices =
      'xterm\n\nMIT License\n\nCopyright (c) 2020 xuty\n'
      '--------------------------------------------------------------------------------\n'
      'engine\nskia\n\nCopyright (c) 2011 Google Inc. All rights reserved.\n';

  Future<ProcessResult> unpack(List<int> compressed) {
    final given = File('${scratch.path}/NOTICES.Z')..writeAsBytesSync(compressed);
    final license = File('${scratch.path}/LICENSE')..writeAsStringSync('GNU GENERAL PUBLIC LICENSE\nVersion 3\n');
    return Process.run('dart', ['tool/third_party_notices.dart', given.path, license.path, '${scratch.path}/out']);
  }

  // Harm: the packages carry the notices compressed, or altered, where a person reads them as text.
  test('the notices are unpacked as plain text, the same as the window shows', () async {
    final result = await unpack(gzip.encode(notices.codeUnits));

    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(File('${scratch.path}/out/THIRD-PARTY-NOTICES').readAsStringSync(), notices);
  });

  // Harm: someone reading the deb's copyright never learns where the third-party licenses are.
  test('the deb\'s copyright names the notices, then holds the window\'s own license', () async {
    await unpack(gzip.encode(notices.codeUnits));

    final copyright = File('${scratch.path}/out/copyright').readAsStringSync();
    expect(copyright.split('\n\n').first, contains('/usr/share/doc/porelo-frontend/THIRD-PARTY-NOTICES'));
    expect(copyright, endsWith('GNU GENERAL PUBLIC LICENSE\nVersion 3\n'));
  });

  // Harm: a package is built with notices nobody can read, and nobody hears of it until a person opens them.
  for (final (what, given) in <(String, List<int>)>[
    ('is not gzip', notices.codeUnits),
    ('holds nothing', gzip.encode(<int>[])),
  ]) {
    test('a NOTICES.Z that $what stops the packaging, writing nothing', () async {
      final result = await unpack(given);

      expect(result.exitCode, 1);
      expect(Directory('${scratch.path}/out').existsSync(), isFalse);
    });
  }

  // Harm: the notices are unpacked but never installed, or installed where neither system looks.
  test('the deb installs the notices beside its copyright, the rpm as a license of its own', () {
    final contents = (loadYaml(File('packaging/nfpm.yaml.in').readAsStringSync()) as YamlMap)['contents'] as YamlList;
    String? sourceOf(String destination, String packager) => contents
        .cast<YamlMap>()
        .where((entry) => entry['dst'] == destination && entry['packager'] == packager)
        .map((entry) => '${entry['src']} ${entry['type'] ?? 'file'}')
        .firstOrNull;

    expect(
      sourceOf('/usr/share/doc/porelo-frontend/THIRD-PARTY-NOTICES', 'deb'),
      'build/notices/THIRD-PARTY-NOTICES file',
    );
    expect(sourceOf('/usr/share/doc/porelo-frontend/copyright', 'deb'), 'build/notices/copyright file');
    expect(
      sourceOf('/usr/share/licenses/porelo-frontend/THIRD-PARTY-NOTICES', 'rpm'),
      'build/notices/THIRD-PARTY-NOTICES license',
    );
    expect(
      File('tool/package.sh').readAsStringSync(),
      contains('dart tool/third_party_notices.dart "\$bundle/data/flutter_assets/NOTICES.Z" LICENSE build/notices'),
    );
  });
}
