// Linux only: it runs the step's script in Bash, with `sha256sum` and `install`.
@Tags(<String>['linux'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/step/the_test_machine_has_porelos_stub_agent.dart';

/// Holds the script that puts Porelo's stub agent onto the test machine to taking the newest snapshot its folder on
/// Artifactory holds, checked against that version's own digest, run here against a stand-in for the folder.
void main() {
  late Directory scratch;
  late Directory home;
  late Directory serve;
  late Directory bin;

  const base = 'https://fuinorg.jfrog.io/artifactory/';
  const folder = 'porelo-dist-test/porelo-agent-stub';

  setUp(() {
    scratch = Directory.systemTemp.createTempSync('stub-agent-');
    home = Directory('${scratch.path}/home')..createSync();
    serve = Directory('${scratch.path}/serve')..createSync();
    bin = Directory('${scratch.path}/bin')..createSync();
    // Serves what the folder holds from serve/, keeping each call's arguments; a path it lacks answers as a 404 does.
    final curl = File('${bin.path}/curl')
      ..writeAsStringSync('''
#!/usr/bin/env bash
echo "\$*" >>"${scratch.path}/curl.calls"
out= url=
while [ \$# -gt 0 ]; do
  case \$1 in
  -o) out=\$2; shift 2 ;;
  --proto | --proto-redir | --connect-timeout | --max-time | -m) shift 2 ;;
  -*) shift ;;
  *) url=\$1; shift ;;
  esac
done
path=\${url#$base}
[ "\$path" != "\$url" ] || exit 6
[ -f "${serve.path}/\$path" ] || exit 22
if [ -n "\$out" ]; then cp -- "${serve.path}/\$path" "\$out"; else cat -- "${serve.path}/\$path"; fi
''');
    // Names the stub only once its yaml is in place, as Porelo reads agents.d.
    final porelo = File('${bin.path}/porelo')
      ..writeAsStringSync(r'''
#!/usr/bin/env bash
[ "$1" = agents ] || exit 2
echo 'NAME   EXECUTABLE'
echo 'codex  /usr/bin/codex'
if [ -f "$HOME/.local/share/porelo/agents.d/stub.yaml" ]; then echo 'stub   stub'; fi
''');
    Process.runSync('chmod', <String>['755', curl.path, porelo.path]);
  });
  tearDown(() => scratch.deleteSync(recursive: true));

  /// Lists [versions] as the folder's storage listing answers them.
  void list(Iterable<String> versions) {
    File('${serve.path}/api/storage/$folder')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        '{"repo":"porelo-dist-test","path":"/porelo-agent-stub","children":['
        '${versions.map((each) => '{"uri":"/$each","folder":true}').join(',')}'
        '],"uri":"${base}api/storage/$folder"}',
      );
  }

  /// Puts [binary] under [version] with [digestLine] as its porelo-agent-stub.sha256, by default its own digest.
  void publish(String version, String binary, {String? digestLine}) {
    final dir = Directory('${serve.path}/$folder/$version')..createSync(recursive: true);
    File('${dir.path}/porelo-agent-stub').writeAsStringSync(binary);
    File('${dir.path}/porelo-agent-stub.sha256')
        .writeAsStringSync(digestLine ?? '${sha256.convert(utf8.encode(binary))}  porelo-agent-stub\n');
  }

  ProcessResult run() {
    final script = File('${scratch.path}/step.sh')..writeAsStringSync(installingTheNewestStub);
    return Process.runSync(
      'bash',
      <String>[script.path],
      environment: <String, String>{
        'HOME': home.path,
        'PATH': '${bin.path}:${Platform.environment['PATH']}',
        'TMPDIR': scratch.path,
      },
      includeParentEnvironment: false,
    );
  }

  File installed() => File('${home.path}/.local/lib/porelo-agent-stub/stub');
  File yaml() => File('${home.path}/.local/share/porelo/agents.d/stub.yaml');

  // Harm: a fixed pin falls out of a folder that keeps the newest 20 versions, and the scenarios that need the stub go
  // red on a fresh machine; or the newest is chosen by its letters, so snapshot.999 wins over snapshot.1000.
  test('the newest snapshot by version is taken and installed once its digest checks', () {
    list(<String>['0.5.1~snapshot.998', '0.5.1~snapshot.1000', '0.5.1~snapshot.999', 'maven-metadata.xml']);
    publish('0.5.1~snapshot.998', 'stub 998');
    publish('0.5.1~snapshot.999', 'stub 999');
    publish('0.5.1~snapshot.1000', 'stub 1000');

    final ran = run();

    expect(ran.exitCode, 0, reason: '${ran.stderr}');
    expect(installed().readAsStringSync(), 'stub 1000');
    expect(yaml().readAsStringSync(), 'executable: ${installed().path}\n');
    final digest = sha256.convert(utf8.encode('stub 1000')).toString();
    expect((ran.stderr as String).trim().split('\n'), <Matcher>[
      allOf(contains('0.5.1~snapshot.1000'), contains(digest)),
    ], reason: 'one line names the version and digest taken');
    for (final call in File('${scratch.path}/curl.calls').readAsLinesSync()) {
      expect(call, allOf(contains('-fsSL'), contains('--proto =https'), contains('--max-time')));
    }
  });

  // Harm: a binary changed on its way, or by whoever can write the folder, is run as the scenarios' agent.
  test('a binary whose digest differs from its .sha256 is refused and nothing is installed', () {
    list(<String>['0.5.1~snapshot.536']);
    publish(
      '0.5.1~snapshot.536',
      'stub 536',
      digestLine: '${sha256.convert(utf8.encode('another stub'))}  porelo-agent-stub\n',
    );

    final ran = run();

    expect(ran.exitCode, isNot(0));
    expect(ran.stderr, allOf(contains('0.5.1~snapshot.536'), contains('does not match')));
    expect(installed().existsSync(), isFalse);
    expect(yaml().existsSync(), isFalse);
  });

  // Harm: a .sha256 that holds no digest is taken as nothing to check, and an unchecked binary is installed.
  test('a malformed .sha256 is refused, saying so', () {
    list(<String>['0.5.1~snapshot.536']);
    publish('0.5.1~snapshot.536', 'stub 536', digestLine: '0EAAE49D1F8ACA57  porelo-agent-stub\n');

    final ran = run();

    expect(ran.exitCode, isNot(0));
    expect(ran.stderr, allOf(contains('0.5.1~snapshot.536'), contains('64 lower-case hexadecimal')));
    expect(installed().existsSync(), isFalse);
  });

  // Harm: a folder holding only releases or other files ends in an error that does not say why, and the scenario's
  // failure is read as Porelo's; or a release is taken where a snapshot run uses snapshots throughout.
  test('a listing with no snapshot is refused, saying so', () {
    list(<String>['0.5.1', 'maven-metadata.xml']);

    final ran = run();

    expect(ran.exitCode, isNot(0));
    expect(ran.stderr, contains('no snapshot version'));
    expect(installed().existsSync(), isFalse);
  });

  // Harm: an empty folder, or a listing in a shape no longer read, leaves the version empty, and a URL without one
  // is fetched, failing with words that point nowhere.
  test('an empty listing is refused, saying so', () {
    list(<String>[]);

    final ran = run();

    expect(ran.exitCode, isNot(0));
    expect(ran.stderr, contains('names no version'));
    expect(installed().existsSync(), isFalse);
  });
}
