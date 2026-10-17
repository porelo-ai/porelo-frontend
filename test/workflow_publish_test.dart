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
    return Process.run('bash', <String>['-c', script],
        workingDirectory: scratch.path,
        environment: <String, String>{
          'PATH': '${scratch.path}/bin:${Platform.environment['PATH']}',
          'CHANNEL': 'releases',
          'INDEX_DEB': '${scratch.path}/index-deb',
          'INDEX_RPM': '${scratch.path}/index-rpm',
        });
  }

  const others = 'Package: porelo\nVersion: 0.4.0\nFilename: pool/main/p/porelo/porelo_0.4.0_amd64.deb\n\n'
      'Package: porelo-agent-claude\nVersion: 0.4.0\n'
      'Filename: pool/main/p/porelo-agent-claude/porelo-agent-claude_0.4.0_amd64.deb\n\n';
  const ours = 'Package: porelo-frontend\nVersion: 0.4.0\n'
      'Filename: pool/main/p/porelo-frontend/porelo-frontend_0.4.0_amd64.deb\n\n';
  const othersRpm = '<package><name>porelo-frontend</name><location href="porelo-frontend-0.3.9-1.x86_64.rpm"/>'
      '</package><package><name>porelo</name><location href="porelo-0.4.0-1.x86_64.rpm"/></package>';
  const oursRpm = '<package><name>porelo-frontend</name><location href="porelo-frontend-0.4.0-1.x86_64.rpm"/></package>';

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
