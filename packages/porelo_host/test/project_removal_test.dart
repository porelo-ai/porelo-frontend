// Linux: bash, a real PTY, and SSH/keepassxc-cli stand-ins made executable by chmod.
@Tags(<String>['linux'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';

void main() {
  late Directory scratch;
  late String cli;
  late String database;

  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('project-removal-');
    database = '${scratch.path}/secrets.kdbx';
    await File(database).writeAsString('A stand-in encrypted database');
    cli = '${scratch.path}/keepassxc-cli';
    await File(cli).writeAsString(r'''#!/usr/bin/python3 -I
import os, sys
master = sys.stdin.readline().rstrip('\n')
if master != 'fixture-master':
    sys.exit(1)
if sys.argv[1] == 'ls':
    if sys.argv[-1] == 'shared':
        if os.environ.get('FIXTURE_LIST_FAILURE'):
            sys.exit(74)
        if 'FIXTURE_ENTRY' in os.environ or os.environ.get('FIXTURE_READ_FAILURE'):
            print('forge-central-token')
    else:
        print('shared/')
    sys.exit(0)
if sys.argv[1:5] != ['show', '-s', '-a', 'password'] or sys.argv[-1] != 'shared/forge-central-token':
    sys.exit(64)
if os.environ.get('FIXTURE_READ_FAILURE'):
    sys.exit(74)
value = os.environ.get('FIXTURE_ENTRY')
if value is None:
    sys.exit(1)
sys.stdout.write(value + '\n')
''');
    expect((await Process.run('/usr/bin/chmod', ['700', cli])).exitCode, 0);
  });

  tearDown(() => scratch.delete(recursive: true));

  String feed() => SecretsFile(database, cli: cli).projectRemovalTokenLine();

  Future<ProcessResult> execute(
    List<String> command, {
    String? entry,
    Map<String, String> environment = const {},
    String master = 'fixture-master',
  }) async {
    final process = await Process.start(
      command.first,
      command.skip(1).toList(),
      environment: {'FIXTURE_ENTRY': ?entry, ...environment},
      includeParentEnvironment: false,
    );
    process.stdin.writeln(master);
    await process.stdin.close();
    final output = process.stdout.transform(utf8.decoder).join();
    final errors = process.stderr.transform(utf8.decoder).join();
    return ProcessResult(process.pid, await process.exitCode, await output, await errors);
  }

  Future<ProcessResult> run(String script, {String? entry}) =>
      execute(['/bin/bash', '--noprofile', '--norc', '-c', script], entry: entry);

  // Harm: the helper refuses a labeled or encoded token instead of protecting the repository's central copy.
  test('the project removal feed is exactly one raw token line', () async {
    const token = 'fixture-central-token';
    final script = feed();
    expect(script, isNot(contains(token)));
    final result = await run(script, entry: token);
    expect(result.exitCode, 0);
    expect(result.stdout, '$token\n');
    expect(result.stderr, isNot(contains(token)));
    expect(result.stderr, isNot(contains('fixture-master')));
  });

  // Harm: a project without repositories cannot be removed when an optional token is missing locally.
  test('a missing central token sends no bytes and names the entry', () async {
    final result = await run(feed());
    expect(result.stdout, isEmpty);
    expect(result.stderr, contains('has no entry shared/forge-central-token; nothing was sent.'));
    expect(result.exitCode, 0, reason: 'the host decides whether it needed a token');
  });

  // Harm: normalizing a multiline entry could feed a different credential or violate the host's stdin contract.
  for (final entry in ['first\nsecond', 'first\n', 'first\rsecond']) {
    test('a malformed central token entry sends nothing: ${jsonEncode(entry)}', () async {
      final result = await run(feed(), entry: entry);
      expect(result.exitCode, isNot(0));
      expect(result.stdout, isEmpty);
      expect(result.stderr, contains('shared/forge-central-token must hold one line'));
      expect(result.stderr, isNot(contains(entry)));
    });
  }

  group('the removal terminal command', () {
    late String ssh;
    late Directory replies;
    setUp(() async {
      ssh = '${scratch.path}/ssh';
      replies = await Directory('${scratch.path}/replies').create();
      await File(ssh).writeAsString(r'''#!/usr/bin/python3 -I
import json, os, sys
value = sys.stdin.buffer.read()
entry = os.environ.get('FIXTURE_ENTRY')
expected = b'' if entry is None else (entry + '\n').encode()
with open(os.environ['FIXTURE_OBSERVATION'], 'w') as out:
    json.dump({'input_matches': value == expected, 'input_empty': not value,
               'args': sys.argv[1:], 'terminal': os.isatty(0)}, out)
code = int(os.environ.get('FIXTURE_REMOTE_CODE', '0'))
if code:
    sys.stderr.write('porelo-host-project: no central home; its only copy stays.  \n')
else:
    print('{"project":"orchard","removed":true}')
sys.exit(code)
''');
      expect((await Process.run('/usr/bin/chmod', ['700', ssh])).exitCode, 0);
    });

    List<String> command({String project = 'orchard'}) => projectRemovalFeedCommand(
      project: project,
      secretsFile: SecretsFile(database, cli: cli),
      host: PreparedHost.read({
        'address': '203.0.113.7',
        'endpoint': '203.0.113.7:51820',
        'wireguard_public_key': base64Encode(List.filled(32, 1)),
        'network': '10.73.7.0/24',
        'ssh_host_key': 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
        'ca_sha256': 'a' * 64,
        'homeserver': 'matrix.orchard.porelo.internal',
      }),
      identity: '${scratch.path}/rental key',
      knownHosts: '${scratch.path}/known hosts',
      replyDirectory: replies.path,
      ssh: ssh,
    );

    // Harm: captured password prompts leave the terminal waiting without telling the person to type.
    test('a real terminal sees the master-password prompt before it supplies input', () async {
      final process = await Process.start(
        '/usr/bin/python3',
        [
          '-I',
          '-c',
          r'''
import json, os, pty, select, subprocess, sys, time
master, slave = pty.openpty()
child = subprocess.Popen(sys.argv[1:], stdin=slave, stderr=slave, stdout=subprocess.PIPE)
os.close(slave)
transcript = b''
prompt = False
deadline = time.monotonic() + 3
try:
    while time.monotonic() < deadline:
        if select.select([master], [], [], 0.05)[0]:
            try: transcript += os.read(master, 8192)
            except OSError: break
        if not prompt and b'The master password of ' in transcript:
            prompt = True
            os.write(master, (os.environ['FIXTURE_MASTER'] + '\n').encode())
        if child.poll() is not None: break
    if child.poll() is None: child.kill()
    out = child.communicate(timeout=2)[0]
finally:
    os.close(master)
print(json.dumps({'prompt_before_input': prompt, 'code': child.returncode,
    'leaked': any(os.environ[key].encode() in transcript + out for key in ['FIXTURE_MASTER', 'FIXTURE_ENTRY'])}))
''',
          ...command(),
        ],
        environment: {
          'FIXTURE_MASTER': 'fixture-master',
          'FIXTURE_ENTRY': 'fixture-central-token',
          'FIXTURE_OBSERVATION': '${scratch.path}/observation.json',
        },
        includeParentEnvironment: false,
      );
      await process.stdin.close();
      final output = process.stdout.transform(utf8.decoder).join();
      final errors = process.stderr.transform(utf8.decoder).join();
      expect(await process.exitCode, 0, reason: await errors);
      final observed = jsonDecode(await output);
      expect(observed['prompt_before_input'], isTrue, reason: 'input must not wait behind the captured refusal');
      expect(observed['code'], 0);
      expect(observed['leaked'], isFalse);
    });

    // Harm: a token in SSH arguments, a terminal stdin or an unpinned connection exposes the central forge.
    for (final present in [true, false]) {
      test('pipes ${present ? 'one token line' : 'no bytes when absent'} to pinned root SSH', () async {
        const token = 'fixture-central-token';
        final arguments = command();
        final observation = '${scratch.path}/observation.json';
        expect(arguments.join(' '), isNot(contains(token)));
        final result = await execute(
          arguments,
          entry: present ? token : null,
          environment: {'FIXTURE_OBSERVATION': observation},
        );
        expect(result.exitCode, 0);
        final observed = jsonDecode(await File(observation).readAsString()) as Map;
        expect(observed['input_matches'], isTrue);
        expect(observed['input_empty'], !present);
        expect(observed['terminal'], isFalse);
        expect(observed['args'], [
          ...pinnedHostSshOptions('${scratch.path}/known hosts', '${scratch.path}/rental key'),
          '-o',
          'ConnectTimeout=10',
          '-T',
          '--',
          'root@10.73.7.1',
          '/usr/local/sbin/porelo-host-project remove orchard',
        ]);
        for (final secret in [token, 'fixture-master']) {
          expect('${observed['args']}${result.stdout}${result.stderr}', isNot(contains(secret)));
          for (final file in replies.listSync().whereType<File>()) {
            expect(await file.readAsString(), isNot(contains(secret)));
          }
        }
        expect(result.stdout, '{"project":"orchard","removed":true}\n');
        expect(await File('${replies.path}/answer').readAsString(), result.stdout);
        expect(await File('${replies.path}/refusal').readAsString(), isEmpty);
        if (!present) expect(result.stderr, contains('has no entry shared/forge-central-token'));
      });
    }

    // An existing but unusable token must never authorize tokenless removal.
    for (final failure in ['empty', 'unreadable', 'listing failed']) {
      test('refuses a central token that is $failure', () async {
        final observation = '${scratch.path}/observation.json';
        final result = await execute(
          command(),
          entry: failure == 'empty' ? '' : null,
          environment: {
            'FIXTURE_OBSERVATION': observation,
            if (failure == 'unreadable') 'FIXTURE_READ_FAILURE': '1',
            if (failure == 'listing failed') 'FIXTURE_LIST_FAILURE': '1',
          },
        );
        expect(result.exitCode, isNot(0), reason: 'an unusable entry is not an absent optional token');
        expect(result.stdout, isEmpty);
        expect(await File(observation).exists(), isFalse, reason: 'no destructive helper is started');
        expect(await File('${replies.path}/answer').readAsString(), isEmpty);
        expect(await File('${replies.path}/refusal').readAsString(), isNotEmpty);
      });
    }

    // A local refusal must prevent a destructive helper from seeing valid tokenless input.
    for (final failure in ['wrong password', 'cancelled', 'multiline token']) {
      test('does not start removal after $failure', () async {
        final observation = '${scratch.path}/observation.json';
        final result = await execute(
          command(),
          master: failure == 'wrong password'
              ? 'wrong\nwrong\nwrong'
              : failure == 'cancelled'
              ? ''
              : 'fixture-master',
          entry: failure == 'multiline token' ? 'first\nsecond' : null,
          environment: {'FIXTURE_OBSERVATION': observation},
        );
        expect(result.exitCode, isNot(0));
        expect(await File(observation).exists(), isFalse, reason: 'SSH must never run after local refusal');
        expect(result.stdout, isEmpty);
      });
    }

    // Harm: a host's protection of a repository's only copy is lost or softened at the terminal boundary.
    test('preserves the helper refusal and exit code with no local token', () async {
      final result = await execute(
        command(),
        environment: {'FIXTURE_OBSERVATION': '${scratch.path}/observation.json', 'FIXTURE_REMOTE_CODE': '65'},
      );
      const refusal = 'porelo-host-project: no central home; its only copy stays.  \n';
      expect(result.exitCode, 65);
      expect(result.stdout, isEmpty);
      expect(await File('${replies.path}/refusal').readAsString(), refusal);
      expect(result.stderr, endsWith(refusal));
    });

    // Harm: inherited startup commands or shell tracing can print credentials before the feed runs.
    test('removal ignores inherited shell startup and tracing', () async {
      final startup = File('${scratch.path}/startup');
      await startup.writeAsString('echo "The caller startup ran" >&2\n');
      final result = await execute(
        command(),
        entry: 'fixture-central-token',
        environment: {
          'FIXTURE_OBSERVATION': '${scratch.path}/observation.json',
          'BASH_ENV': startup.path,
          'ENV': startup.path,
          'SHELLOPTS': 'xtrace',
        },
      );
      expect(result.exitCode, 0);
      expect(result.stderr, isNot(contains('The caller startup ran')));
      expect(result.stderr, isNot(contains('fixture-central-token')));
      expect(result.stderr, isNot(contains('fixture-master')));
    });

    // Harm: project names interpreted by a remote shell can run another command as root.
    test('checks project arguments before a removal terminal can open', () {
      for (final bad in ['--help', 'a;id', "a'b", 'a\nb', r'$(id)']) {
        expect(() => command(project: bad), throwsFormatException);
      }
    });
  });
}
