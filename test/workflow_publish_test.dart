// Linux only: it runs the workflow's publishing steps in Bash.
@Tags(<String>['linux'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Holds the publish steps of `.github/workflows/build.yml` to this package's own files.
///
/// The `releases` index holds every Porelo package, many at the same version. A step that asks
/// only whether some package has that version refuses a release nobody made, and believes an
/// upload indexed that is not. Each step's script is taken from the workflow itself and run
/// against a stand-in `curl` that answers with a chosen index.
void main() {
  late Directory scratch;
  final workflow = File('.github/workflows/build.yml').readAsLinesSync();

  setUp(() {
    scratch = Directory.systemTemp.createTempSync('publish-steps-');
    Directory('${scratch.path}/packages').createSync();
    File('${scratch.path}/packages/porelo-frontend_0.4.0_amd64.deb').writeAsStringSync('');
    File('${scratch.path}/packages/porelo-frontend-0.4.0-1.x86_64.rpm').writeAsStringSync('');
    final bin = Directory('${scratch.path}/bin')..createSync();
    _script('${bin.path}/curl', r'''
for url; do :; done
case "$url" in
  */Packages) cat "$INDEX_DEB" ;;
  */repomd.xml) echo '<location href="repodata/0123abcd-primary.xml.gz"/>' ;;
  *-primary.xml.gz) gzip -c "$INDEX_RPM" ;;
  *) exit 22 ;;
esac
''');
    _script('${bin.path}/dpkg-deb', 'echo 0.4.0');
    _script('${bin.path}/sleep', 'exit 0');
  });

  tearDown(() => scratch.deleteSync(recursive: true));

  Future<ProcessResult> run(String step, {required String deb, required String rpm}) {
    File('${scratch.path}/index-deb').writeAsStringSync(deb);
    File('${scratch.path}/index-rpm').writeAsStringSync(rpm);
    final script = _runOf(workflow, step).replaceAll(r'${{ vars.JF_URL }}', 'https://example.invalid');
    return Process.run(
      'bash',
      <String>['-c', script],
      workingDirectory: scratch.path,
      environment: <String, String>{
        'PATH': '${scratch.path}/bin:${Platform.environment['PATH']}',
        'CHANNEL': 'releases',
        'ART_BASE': 'https://example.invalid/artifactory',
        'INDEX_DEB': '${scratch.path}/index-deb',
        'INDEX_RPM': '${scratch.path}/index-rpm',
      },
    );
  }

  const others =
      'Package: porelo\nVersion: 0.4.0\nFilename: pool/main/p/porelo/porelo_0.4.0_amd64.deb\n\n'
      'Package: porelo-agent-claude\nVersion: 0.4.0\n'
      'Filename: pool/main/p/porelo-agent-claude/porelo-agent-claude_0.4.0_amd64.deb\n\n';
  const ours =
      'Package: porelo-frontend\nVersion: 0.4.0\n'
      'Filename: pool/main/p/porelo-frontend/porelo-frontend_0.4.0_amd64.deb\n\n';
  const othersRpm =
      '<package><name>porelo-frontend</name><location href="porelo-frontend-0.3.9-1.x86_64.rpm"/>'
      '</package><package><name>porelo</name><location href="porelo-0.4.0-1.x86_64.rpm"/></package>';
  const oursRpm =
      '<package><name>porelo-frontend</name><location href="porelo-frontend-0.4.0-1.x86_64.rpm"/></package>';

  // The harm: the token on a command line, in a file or in the job's environment, where a secret must
  // never be in CI, or every upload sent to an address Artifactory does not serve because `JF_URL`
  // came with or without `/artifactory`.
  group('the token and the address', () {
    Future<({ProcessResult result, String env, Directory temp})> give(
      String jfUrl, {
      String token = 'tok-e2e-secret',
    }) async {
      final temp = Directory('${scratch.path}/temp')..createSync();
      final env = File('${scratch.path}/github-env')..writeAsStringSync('');
      final result = await Process.run(
        'bash',
        <String>['-e', '-c', _runOf(workflow, 'Give curl the address')],
        workingDirectory: scratch.path,
        environment: <String, String>{
          'PATH': '${scratch.path}/bin:${Platform.environment['PATH']}',
          'JF_URL': jfUrl,
          'JF_ACCESS_TOKEN': token,
          'RUNNER_TEMP': temp.path,
          'GITHUB_ENV': env.path,
        },
      );
      return (result: result, env: env.readAsStringSync(), temp: temp);
    }

    for (final jfUrl in <String>[
      'https://example.invalid',
      'https://example.invalid/',
      'https://example.invalid/artifactory',
      'https://example.invalid/artifactory//',
    ]) {
      test('$jfUrl becomes the address raw curl needs', () async {
        final given = await give(jfUrl);
        expect(given.result.exitCode, 0, reason: '${given.result.stderr}');
        expect(given.env, contains('ART_BASE=https://example.invalid/artifactory\n'), reason: given.env);
      });
    }

    test('the token goes nowhere but its own steps: no file, not the job environment', () async {
      final given = await give('https://example.invalid');
      expect(given.temp.listSync(), isEmpty, reason: 'a file was written where the token could be');
      expect(given.env, isNot(contains('tok-e2e-secret')), reason: 'the token went into the job environment');
      expect('${given.result.stdout}${given.result.stderr}', isNot(contains('tok-e2e-secret')));
    });

    test('a missing token is refused before anything is written', () async {
      final given = await give('https://example.invalid', token: '');
      expect(given.result.exitCode, isNot(0));
      expect(given.env, isNot(contains('ART_BASE')));
    });

    test('an upload hands curl the token on standard input, never as an argument or a file', () async {
      final temp = Directory('${scratch.path}/temp')..createSync();
      final seen = File('${scratch.path}/curl-seen');
      // A curl that records its arguments and what it read on standard input.
      _script(
        '${scratch.path}/bin/curl',
        'printf "%s\\n" "\$@" >> "${seen.path}.args"; cat >> "${seen.path}.stdin"; exit 0',
      );
      final result = await Process.run(
        'bash',
        <String>['-e', '-c', _runOf(workflow, 'Upload the deb and the rpm')],
        workingDirectory: scratch.path,
        environment: <String, String>{
          'PATH': '${scratch.path}/bin:${Platform.environment['PATH']}',
          'JF_ACCESS_TOKEN': 'tok-e2e-secret',
          'ART_BASE': 'https://example.invalid/artifactory',
          'CHANNEL': 'snapshots',
          'RUNNER_TEMP': temp.path,
        },
      );
      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(
        File('${seen.path}.stdin').readAsStringSync(),
        'header = "Authorization: Bearer tok-e2e-secret"\n' * 2,
        reason: 'each of the two uploads reads its config on standard input',
      );
      expect(File('${seen.path}.args').readAsStringSync(), isNot(contains('tok-e2e-secret')));
      expect(temp.listSync(), isEmpty, reason: 'a file was written where the token could be');
    });
  });

  test('a release is not refused because another package has its version', () async {
    final result = await run('Refuse a release that is there already', deb: others, rpm: othersRpm);
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
  });

  test('a release of this package that is there already is refused', () async {
    final result = await run('Refuse a release that is there already', deb: others + ours, rpm: oursRpm);
    expect(result.exitCode, isNot(0), reason: 'a second upload of 0.4.0 went through');
  });

  test('an upload is not believed indexed because another package has its version', () async {
    final result = await run('Wait until it is actually indexed', deb: others, rpm: othersRpm);
    expect(result.exitCode, isNot(0), reason: 'took other packages for this one:\n${result.stdout}');
  });

  // The harm: the deb indexed and the rpm not yet, and the build saying the release is served.
  test('an upload is not believed indexed while only the deb index names it', () async {
    final result = await run('Wait until it is actually indexed', deb: others + ours, rpm: othersRpm);
    expect(result.exitCode, isNot(0), reason: 'took the deb alone for both:\n${result.stdout}');
  });

  test('an upload is believed indexed once both indexes name its own files', () async {
    final result = await run('Wait until it is actually indexed', deb: others + ours, rpm: othersRpm + oursRpm);
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
  });
}

void _script(String path, String body) {
  File(path).writeAsStringSync('#!/bin/sh\n$body\n');
  Process.runSync('chmod', <String>['755', path]);
}

/// The `run: |` block of the step named [step], unindented.
String _runOf(List<String> workflow, String step) {
  final at = workflow.indexWhere((line) => line.trim() == '- name: $step');
  expect(at, isNot(-1), reason: 'no step "$step" in the workflow');
  final run = workflow.indexWhere((line) => line.trim() == 'run: |', at);
  final indent = workflow[run].indexOf('run:') + 2;
  final body = <String>[];
  for (final line in workflow.skip(run + 1)) {
    if (line.trim().isNotEmpty && line.length - line.trimLeft().length < indent) break;
    body.add(line.length >= indent ? line.substring(indent) : '');
  }
  return body.join('\n');
}
