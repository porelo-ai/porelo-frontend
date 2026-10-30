// Linux: these terminal feeds require Bash, chmod, and keepassxc-cli.
@Tags(['linux'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:porelo_host/porelo_host.dart';
import 'package:porelo_frontend/src/app/host_stop_feed.dart';

/// The stop's terminal when the host takes its secrets from the person's file, on standard input.
void main() {
  group('entry preflight', _preflightTests);
  List<String> command({
    List<String> needs = const ['vault-new', 'wireguard'],
    List<String> keys = const [],
    String email = '',
    String ssh = '/usr/bin/ssh',
    String host = 'ubuntu@203.0.113.7',
    String? driveHost = 'porelo@203.0.113.7',
    String secretsFile = '/home/person/Porelo/secrets.kdbx',
    String cli = SecretsFile.keepassxcCli,
  }) => hostStopFeedCommand(
    act: HostAct.legacyUp,
    secretsFile: secretsFile,
    cli: cli,
    project: 'checkout',
    needs: needs,
    keys: keys,
    email: email,
    ssh: ssh,
    sshOptions: const ['-o', 'StrictHostKeyChecking=yes'],
    host: host,
    driveHost: driveHost,
  );

  // Harm: the caller's startup files or an inherited trace run beside the master password.
  test('runs a clean bash on this desktop', () {
    final run = command();
    expect(run.first, '/usr/bin/env');
    expect(run.join(' '), allOf(contains('-u BASH_ENV'), contains('-u SHELLOPTS')));
    expect(run, containsAllInOrder(<String>['/bin/bash', '--noprofile', '--norc', '-c']));
  });

  // Harm: the host is sent lines for the wrong stop, or takes them as a prompt it never asked.
  test('pipes the file\'s lines into exactly the stop the host named, on standard input', () {
    final script = command().last;
    expect(script, contains("'projects/checkout/vault-passphrase'"));
    expect(script, contains("'hosts/checkout/wireguard'"));
    final pipe = script.substring(script.lastIndexOf('} | '));
    expect(
      pipe,
      endsWith(
        '/usr/bin/ssh -o StrictHostKeyChecking=yes -T -- ubuntu@203.0.113.7 '
        "'/usr/bin/sudo -n /usr/local/bin/porelo-host-stop --stdin vault-new wireguard'",
      ),
      reason: 'ssh and sudo by their paths, no login shell whose profile could read the pipe, no password asked',
    );
    expect(script, contains('set -o pipefail'), reason: 'a feed that fails fails the terminal');
    expect(script.indexOf('} | '), greaterThan(script.indexOf('read -rs')), reason: 'the lines go into the pipe');
    expect(script.indexOf('/usr/bin/stty -echo'), lessThan(script.indexOf('} | ')), reason: 'no echo for the file');
    expect(script, contains("trap '/usr/bin/stty echo"));
  });

  // Harm: the forge signed for a request not its own, or the request read through the pipe that carries the secrets.
  test('the forge\'s request follows the local check and precedes signing, only where it waits', () {
    final script = command(needs: ['forge-certificate']).last;
    final asked = script.indexOf('porelo-host-stop --request');
    expect(asked, greaterThan(-1));
    expect(asked, greaterThan(script.indexOf('read -rs')), reason: 'the file opens before any host command');
    expect(asked, lessThan(script.indexOf('requests=()')), reason: 'the request precedes signing');
    expect(
      script.substring(0, asked),
      contains(" -n -T -- ubuntu@203.0.113.7 "),
      reason: 'as the admin, with no input',
    );
    expect(script, contains('porelo-host-stop --stdin forge-certificate'));
    expect(command().last, isNot(contains('--request')), reason: 'not asked where the host did not name it');
  });

  // Harm: an entry the file keeps from an earlier setup sent to a host whose machine.yml does not name it.
  test('sends the vault entries machine.yml names, only where the host asked for them', () {
    final script = command(needs: ['vault-new', 'keys'], keys: ['forge']).last;
    expect(script, contains("'projects/checkout/keys/forge'"));
    expect(command(needs: ['vault'], keys: ['forge']).last, isNot(contains('keys/forge')));
  });

  // Harm: the drive's login typed into a pipe that carries the other secrets.
  test('asks the drive in its own terminal first, then feeds the rest', () {
    final script = command(needs: ['drive', 'vault'], email: 'me@example.org').last;
    final drive = script.indexOf("'drive'");
    expect(drive, greaterThan(-1));
    expect(drive, lessThan(script.indexOf('--stdin vault')));
    final login = script.split('\n').firstWhere((line) => line.contains(' -t '));
    expect(login, contains(' -t -- porelo@203.0.113.7 '), reason: 'the drive logs in as the account');
    expect(login, endsWith(' || exit \$?'), reason: 'a failed login sends nothing after it');
    expect(
      script.lastIndexOf('/usr/bin/stty -echo'),
      greaterThan(script.indexOf(' -t ')),
      // ssh hands this terminal's modes to the far end's: with echo off there, the e-mail typed would not show.
      reason: 'echo is hidden again after the drive\'s login',
    );
    expect(script.substring(0, script.indexOf('--stdin')), contains('me@example.org'));
    expect(script.substring(script.indexOf('--stdin')), isNot(contains('drive')));
  });

  // Harm: the host's registration token through an argument, a field or a log of this program, or the master
  // password asked for a token the secrets file has no part in.
  test('the host\'s matrix token comes from this computer\'s own Porelo, on the pipe, and alone needs no file', () {
    final only = command(needs: ['matrix-token']).last;
    expect(
      only,
      contains("/usr/bin/ssh -o StrictHostKeyChecking=yes -n -T -- ubuntu@203.0.113.7 /usr/bin/hostname"),
      reason: 'the host\'s name read on the host, as its Porelo will pass it',
    );
    expect(
      only,
      contains('/usr/bin/porelo talk admit checkout "\$machine" --into "\$admitted/admission.json"'),
      reason: 'the project and the host\'s machine name, the admission into a folder of its own',
    );
    expect(only.indexOf('talk admit'), greaterThan(only.indexOf("case \"\$machine\" in")), reason: 'checked first');
    expect(only, contains('/usr/bin/python3 -I'), reason: 'the token read from the file, never on a command line');
    expect(only, contains("printf 'matrix-token %s\\n'"));
    expect(
      only,
      isNot(contains('/usr/bin/printf')),
      reason: 'the shell\'s own printf: the token in no process\'s arguments',
    );
    expect(only, isNot(contains('read -rs')), reason: 'no master password for what the file does not give');
    expect(only, contains("'/usr/bin/sudo -n /usr/local/bin/porelo-host-stop --stdin matrix-token'"));
    expect(only, contains('rm -rf -- "\$admitted"'), reason: 'the admission goes with the terminal');
    final both = command(needs: ['vault', 'matrix-token']).last;
    expect(both, contains('read -rs'), reason: 'the vault still comes from the file');
    final pipe = both.substring(both.indexOf('{\n'), both.lastIndexOf('} | '));
    expect(
      pipe,
      allOf(contains("'projects/checkout/vault-passphrase'"), contains("printf 'matrix-token %s\\n'")),
      reason: 'both go on the one pipe',
    );
    expect(both, contains('--stdin vault matrix-token'));
  });

  test('a project that would read as an option is let in nowhere', () {
    expect(
      () => hostStopFeedCommand(
        act: HostAct.legacyUp,
        secretsFile: '',
        project: '--help',
        needs: const ['matrix-token'],
        ssh: '/usr/bin/ssh',
        sshOptions: const [],
        host: 'ubuntu@203.0.113.7',
      ),
      throwsFormatException,
    );
  });

  test('refuses a need the file cannot give, and a stop with nothing for the file', () {
    expect(() => command(needs: ['no-such-need']), throwsFormatException);
    expect(() => command(needs: ['drive'], email: 'me@example.org'), throwsFormatException);
  });

  // Harm: the secrets piped into whatever `ssh` PATH finds, or an option read where a host was meant.
  test('refuses an ssh by name, and a host or drive login that is no user at an address', () {
    expect(() => command(ssh: 'ssh'), throwsFormatException);
    for (final bad in <String>['-oProxyCommand=x', '203.0.113.7', "a@b'c", 'a@-b']) {
      expect(() => command(host: bad), throwsFormatException, reason: bad);
      expect(
        () => command(needs: ['drive', 'vault'], driveHost: bad),
        throwsFormatException,
        reason: bad,
      );
    }
  });

  // Harm: the host's token read wrongly, sent as more than one line, sent after a step failed, or left on this
  // computer once it is read.
  group('the stand-in host and this computer\'s stand-in Porelo', () {
    late Directory home;
    late String got;
    late String calls;
    late String intoFile;
    late String still;
    setUp(() async {
      home = await Directory.systemTemp.createTemp('porelo-stop-feed-test-');
      got = path.join(home.path, 'got');
      calls = path.join(home.path, 'calls');
      intoFile = path.join(home.path, 'into');
      still = path.join(home.path, 'still');
    });
    tearDown(() => home.delete(recursive: true));

    /// Runs the feed for the matrix token alone; [name] is what the host says it is, [nameExit] how its ssh ends,
    /// [admitExit] how this computer's Porelo ends, [token] what its admission holds.
    Future<int> feed({
      String name = 'checkout-host',
      int nameExit = 0,
      int admitExit = 0,
      String token = 'tok en',
    }) async {
      final fakeSsh = File(path.join(home.path, 'ssh'))
        ..writeAsStringSync(
          '#!/bin/sh\n'
          'case "\$*" in\n'
          "  *hostname*) printf '%s\\n' '$name'; exit $nameExit;;\n"
          // Whether the admission still lies on this computer while its token goes over the pipe.
          '  *porelo-host-stop*) [ -e "\$(cat $intoFile)" ] && echo still > $still; cat > $got;;\n'
          'esac\n',
        );
      // Every call is written down first, whatever it is asked: a Porelo asked at all is seen.
      final fakePorelo = File(path.join(home.path, 'porelo'))
        ..writeAsStringSync(
          '#!/bin/sh\n'
          'printf \'%s|\' "\$@" >> $calls; echo >> $calls\n'
          '[ $admitExit = 0 ] || exit $admitExit\n'
          'printf \'%s\' "\$6" > $intoFile\n'
          'printf \'{"admission":{"machine":"%s"},"secrets":{"registration_token":"%s"}}\' "\$4" \'$token\' > "\$6"\n',
        );
      for (final file in [fakeSsh, fakePorelo]) {
        await Process.run('chmod', ['700', file.path]);
      }
      final run = command(needs: ['matrix-token'], ssh: fakeSsh.path);
      final script = run.last.replaceAll('/usr/bin/porelo talk', '${fakePorelo.path} talk');
      final process = await Process.start(run.first, [...run.skip(1).take(run.length - 2), script]);
      await process.stdin.close();
      await process.stdout.drain<void>();
      await process.stderr.drain<void>();
      return process.exitCode;
    }

    List<String> admitted() => File(calls).existsSync() ? File(calls).readAsLinesSync() : const [];

    test('gets exactly its matrix token line, and the admission is gone at once', () async {
      expect(await feed(), 0);
      expect(File(got).readAsStringSync(), 'matrix-token ${base64.encode(utf8.encode('tok en'))}\n');
      final into = admitted().single.split('|')[5];
      expect(admitted().single, startsWith('talk|admit|checkout|checkout-host|--into|'));
      expect(File(into).existsSync(), isFalse, reason: 'the admission goes once its token is read');
      expect(File(still).existsSync(), isFalse, reason: 'gone before the pipe, not only at the terminal\'s end');
      expect(File(into).parent.existsSync(), isFalse);
    });

    test('a host whose name reads as an option, or holds what a shell splits, is let in nowhere', () async {
      for (final name in ['-rf', 'a b', r'x$y', '.', '..', '_x', 'ä']) {
        expect(await feed(name: name), isNot(0), reason: name);
        expect(File(got).existsSync(), isFalse, reason: 'nothing sent for $name');
        expect(admitted(), isEmpty, reason: 'this computer\'s Porelo not asked for $name');
      }
    });

    test('nothing is sent where the host gave no name, Porelo refused, or the admission held no token', () async {
      for (final (why, run) in [
        ('no name', () => feed(nameExit: 255)),
        ('admit refused', () => feed(admitExit: 1)),
        ('an empty token', () => feed(token: '')),
      ]) {
        if (File(intoFile).existsSync()) File(intoFile).deleteSync();
        expect(await run(), isNot(0), reason: why);
        expect(File(got).existsSync(), isFalse, reason: 'nothing sent: $why');
        if (File(intoFile).existsSync()) {
          final into = File(File(intoFile).readAsStringSync());
          expect(into.parent.existsSync(), isFalse, reason: 'the admission goes with the terminal: $why');
        }
      }
    });
  }, skip: Platform.isWindows ? 'the feed runs bash and chmod, which only Linux has here' : null);

  // Against the real keepassxc-cli: what reaches the far end is the lines and nothing else.
  // Harm: a Tresorit login that failed, and the secrets piped after it all the same.
  test('a drive login that fails ends the terminal after the entry check and before the feed', () async {
    final home = await Directory.systemTemp.createTemp('porelo-stop-feed-test-');
    addTearDown(() => home.delete(recursive: true));
    final calls = path.join(home.path, 'calls');
    final fakeSsh = await File(path.join(home.path, 'ssh')).writeAsString('#!/bin/sh\necho "\$@" >> $calls\nexit 3\n');
    final database = await File(path.join(home.path, 'secrets.kdbx')).writeAsString('An encrypted database stand-in');
    final cli = await File(path.join(home.path, 'keepassxc-cli')).writeAsString(r'''#!/usr/bin/python3 -I
import sys
sys.stdin.readline()
if sys.argv[1] == 'ls' and sys.argv[-1].endswith('.kdbx'):
    if '-f' in sys.argv: print('projects/checkout/vault-passphrase')
elif sys.argv[1:5] == ['show', '-s', '-a', 'password'] and sys.argv[-1] == 'projects/checkout/vault-passphrase':
    print('fixture-passphrase')
else: sys.exit(1)
''');
    for (final program in [fakeSsh, cli]) {
      expect((await Process.run('chmod', ['700', program.path])).exitCode, 0);
    }
    final run = command(
      needs: ['drive', 'vault'],
      email: 'me@example.org',
      ssh: fakeSsh.path,
      secretsFile: database.path,
      cli: cli.path,
    );
    final process = await Process.start(run.first, run.skip(1).toList());
    process.stdin.writeln('fixture-master');
    await process.stdin.close();
    await process.stdout.drain<void>();
    await process.stderr.drain<void>();
    expect(await process.exitCode, 3, reason: 'the login\'s own exit');
    expect(await File(calls).readAsLines(), hasLength(1), reason: 'no second ssh, no pipe');
  }, skip: Platform.isWindows ? 'the feed runs bash and chmod, which only Linux has here' : null);

  group('run', () {
    final cli = Platform.environment['KEEPASSXC_CLI'] ?? SecretsFile.keepassxcCli;
    final skip = File(cli).existsSync() ? null : 'needs keepassxc-cli at $cli (set KEEPASSXC_CLI) and wg';

    // Harm: the lasting password goes to the wrong login, appears in arguments, or a failed receiver looks successful.
    test('the lasting password reaches only the own-login command on standard input', () async {
      final home = await Directory.systemTemp.createTemp('porelo-forge-password-test-');
      addTearDown(() => home.delete(recursive: true));
      final kdbx = path.join(home.path, 'secrets.kdbx');
      Future<ProcessResult> run(List<String> command, String input) async {
        final process = await Process.start(command.first, command.skip(1).toList());
        final out = process.stdout.transform(utf8.decoder).join();
        final err = process.stderr.transform(utf8.decoder).join();
        process.stdin.write(input);
        await process.stdin.close();
        return ProcessResult(process.pid, await process.exitCode, await out, await err);
      }

      final made = await run([
        'bash',
        '-c',
        SecretsFile(
          kdbx,
          cli: cli,
        ).prepareHost(host: 'checkout', project: 'checkout', create: true, publicKeyOut: path.join(home.path, 'k.pub')),
      ], 'm\nm\n');
      expect(made.exitCode, 0, reason: '${made.stderr}');
      final random = Random.secure();
      final password = base64Encode(List<int>.generate(24, (_) => random.nextInt(256)));
      final digest = await run(['/usr/bin/openssl', 'dgst', '-sha256'], '$password\n');
      expect(digest.exitCode, 0);
      final calls = File(path.join(home.path, 'calls'));
      final ssh = File(path.join(home.path, 'ssh'));
      await ssh.writeAsString(
        '#!/bin/sh\nprintf \'%s\\n\' "\$@" > "${calls.path}"\nexec /usr/bin/openssl dgst -sha256\n',
      );
      expect((await Process.run('/usr/bin/chmod', ['700', ssh.path])).exitCode, 0);
      final command = hostForgePasswordFeedCommand(
        secretsFile: kdbx,
        ssh: ssh.path,
        sshOptions: const ['-o', 'BatchMode=yes'],
        host: 'person@203.0.113.7',
        cli: cli,
      );
      final first = await run(command, 'm\n$password\n$password\n');
      expect(first.exitCode, 0, reason: '${first.stderr}');
      expect(first.stdout, digest.stdout, reason: 'the receiver hashes exactly the password line');
      expect('${first.stderr}'.contains(password), isFalse);
      expect(command.any((argument) => argument.contains(password)), isFalse);
      expect(await calls.readAsLines(), [
        '-o',
        'BatchMode=yes',
        '-T',
        '--',
        'person@203.0.113.7',
        '/usr/bin/sudo -n /usr/local/sbin/porelo-host-forge-password',
      ], reason: 'no login name or password is a remote command argument');
      final again = await run(command, 'm\n');
      expect(again.exitCode, 0, reason: '${again.stderr}');
      expect(again.stdout, digest.stdout, reason: 'another use takes the shared lasting password');
      await ssh.writeAsString('#!/bin/sh\n/usr/bin/openssl dgst -sha256 >/dev/null\nexit 9\n');
      final refused = await run(command, 'm\n');
      expect(refused.exitCode, 9, reason: 'the host refusal propagates through the pipe');
    }, skip: skip);

    test('the stand-in host gets exactly the file\'s lines on its standard input', () async {
      final home = await Directory.systemTemp.createTemp('porelo-stop-feed-test-');
      addTearDown(() => home.delete(recursive: true));
      final kdbx = path.join(home.path, 'secrets.kdbx');
      final made = await Process.start('bash', [
        '-c',
        SecretsFile(
          kdbx,
          cli: cli,
        ).prepareHost(host: 'checkout', project: 'checkout', create: true, publicKeyOut: path.join(home.path, 'k.pub')),
      ]);
      made.stdin.write('m\nm\n');
      await made.stdin.close();
      await made.stdout.drain<void>();
      await made.stderr.drain<void>();
      expect(await made.exitCode, 0);
      final received = path.join(home.path, 'received');
      final fakeSsh = await File(path.join(home.path, 'ssh')).writeAsString('#!/bin/sh\ncat > $received\n');
      await Process.run('chmod', ['700', fakeSsh.path]);

      final run = hostStopFeedCommand(
        act: HostAct.legacyUp,
        secretsFile: kdbx,
        project: 'checkout',
        needs: ['vault-new', 'wireguard'],
        ssh: fakeSsh.path,
        sshOptions: const [],
        host: 'ubuntu@203.0.113.7',
        cli: cli,
      );
      final process = await Process.start(run.first, run.skip(1).toList());
      process.stdin.write('m\n');
      await process.stdin.close();
      final shown =
          '${await process.stdout.transform(utf8.decoder).join()}${await process.stderr.transform(utf8.decoder).join()}';

      expect(await process.exitCode, 0, reason: shown);
      final lines = (await File(received).readAsString()).trim().split('\n');
      expect(lines.map((line) => line.split(' ').first), ['vault-new', 'wireguard']);
      final key = utf8.decode(base64Decode(lines.last.split(' ').last));
      expect(await HostFiles.publicKey(key), (await File(path.join(home.path, 'k.pub')).readAsString()).trim());
      expect(shown, isNot(contains(key)), reason: 'nothing of it on this desktop\'s terminal');
    }, skip: skip);
  });

  group('the vault unlocked from the file', () {
    List<String> unlock({String host = 'porelo@203.0.113.7'}) => hostUnlockFeedCommand(
      secretsFile: '/home/person/Porelo/secrets.kdbx',
      project: 'checkout',
      ssh: '/usr/bin/ssh',
      sshOptions: const ['-o', 'StrictHostKeyChecking=yes'],
      host: host,
    );

    // Harm: the vault passphrase on a command line, or the pipe read by a login shell's profile at the far end.
    test('pipes the file\'s vault passphrase into the account\'s own porelo, on standard input', () {
      final run = unlock();
      expect(run, containsAllInOrder(<String>['/usr/bin/env', '/bin/bash', '--noprofile', '--norc', '-c']));
      final script = run.last;
      expect(script, contains("'projects/checkout/vault-passphrase'"));
      expect(
        script.substring(script.lastIndexOf('} | ')),
        endsWith(
          '/usr/bin/ssh -o StrictHostKeyChecking=yes -T -- porelo@203.0.113.7 '
          "'/usr/bin/porelo vault unlock --passphrase-stdin'",
        ),
      );
      expect(script, contains('set -o pipefail'), reason: 'a feed that fails fails the terminal');
      expect(script.indexOf('/usr/bin/stty -echo'), lessThan(script.indexOf('} | ')), reason: 'no echo for the file');
    });

    test('refuses a host that is not one login at one address', () {
      expect(() => unlock(host: '-oProxyCommand=x'), throwsFormatException);
    });
  });
}

void _preflightTests() {
  late Directory scratch;
  late String cli;
  late String ssh;
  late String database;
  late String observation;
  late Map<String, String> caEntries;
  const entries = ['projects/demo/vault-passphrase', 'projects/demo/keys/forge', 'shared/forge-central-token'];

  setUpAll(() async {
    final key = await Process.run('/usr/bin/openssl', [
      'genpkey',
      '-algorithm',
      'EC',
      '-pkeyopt',
      'ec_paramgen_curve:P-256',
    ]);
    expect(key.exitCode, 0);
    final certificate = await Process.start('/usr/bin/openssl', [
      'req',
      '-x509',
      '-new',
      '-key',
      '/dev/stdin',
      '-subj',
      '/CN=fixture',
    ]);
    final output = certificate.stdout.transform(utf8.decoder).join();
    final errors = certificate.stderr.transform(utf8.decoder).join();
    certificate.stdin.write(key.stdout);
    await certificate.stdin.close();
    expect(await certificate.exitCode, 0, reason: await errors);
    caEntries = {
      'hosts/demo/forge-ca-key': base64Encode(utf8.encode(key.stdout as String)),
      'hosts/demo/forge-ca': base64Encode(utf8.encode(await output)),
    };
  });

  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('stop-preflight-');
    database = '${scratch.path}/secrets.kdbx';
    await File(database).writeAsString('An encrypted database stand-in');
    observation = '${scratch.path}/observation.json';
    cli = '${scratch.path}/keepassxc-cli';
    ssh = '${scratch.path}/ssh';
    await File(cli).writeAsString(r'''#!/usr/bin/python3 -I
import json, os, sys
if sys.stdin.readline().rstrip('\n') != os.environ['FIXTURE_MASTER']: sys.exit(1)
entries = json.loads(os.environ['FIXTURE_ENTRIES'])
if sys.argv[1] == 'ls':
    if '-f' in sys.argv:
        if os.environ.get('FIXTURE_LIST_FAILURE'): sys.exit(74)
        print('\n'.join(entries))
    elif sys.argv[-1] != os.environ['FIXTURE_DATABASE']:
        sys.exit(1)
elif sys.argv[1] == 'show' and sys.argv[-1] in entries:
    if '-s' in sys.argv:
        if os.environ.get('FIXTURE_READ_FAILURE') in ['all', sys.argv[-1]]: sys.exit(74)
        print(json.loads(os.environ['FIXTURE_VALUES']).get(sys.argv[-1], os.environ['FIXTURE_VALUE']))
else:
    sys.exit(1)
''');
    await File(ssh).writeAsString(r'''#!/usr/bin/python3 -I
import base64, json, os, sys
value = os.environ['FIXTURE_VALUE']
encoded = base64.b64encode(value.encode()).decode()
expected = f'vault {encoded}\nkey forge {value}\nforge-central-token {encoded}\n'
with open(os.environ['FIXTURE_OBSERVATION'], 'w') as out:
    json.dump({'input_matches': sys.stdin.read() == expected,
        'secret_argument': any(value in arg or os.environ['FIXTURE_MASTER'] in arg for arg in sys.argv),
        'terminal': os.isatty(0)}, out)
''');
    for (final program in [cli, ssh]) {
      expect((await Process.run('/usr/bin/chmod', ['700', program])).exitCode, 0);
    }
  });
  tearDown(() => scratch.delete(recursive: true));

  Future<ProcessResult> run({
    List<String> present = entries,
    String? failure,
    Map<String, String> values = const {},
    String? unreadable,
    List<String> needs = const ['vault', 'keys', 'forge-central-token'],
    HostAct act = HostAct.ownAccount,
  }) async {
    final command = hostStopFeedCommand(
      act: act,
      secretsFile: database,
      project: 'demo',
      needs: needs,
      keys: ['forge'],
      ssh: ssh,
      sshOptions: pinnedHostSshOptions('${scratch.path}/known_hosts', '${scratch.path}/identity'),
      host: 'person@203.0.113.7',
      cli: cli,
      email: 'person@example.org',
    );
    final random = Random.secure();
    String secret() => base64Encode(List.generate(24, (_) => random.nextInt(256)));
    final master = secret();
    final value = secret();
    final process = await Process.start(
      command.first,
      command.skip(1).toList(),
      environment: {
        'FIXTURE_MASTER': master,
        'FIXTURE_VALUE': value,
        'FIXTURE_VALUES': jsonEncode(values),
        'FIXTURE_ENTRIES': jsonEncode(present),
        'FIXTURE_DATABASE': database,
        'FIXTURE_OBSERVATION': observation,
        if (failure == 'list') 'FIXTURE_LIST_FAILURE': '1',
        if (failure == 'read' || unreadable != null) 'FIXTURE_READ_FAILURE': unreadable ?? 'all',
      },
      includeParentEnvironment: false,
    );
    final output = process.stdout.transform(utf8.decoder).join();
    final errors = process.stderr.transform(utf8.decoder).join();
    process.stdin.writeln(master);
    await process.stdin.close();
    final result = ProcessResult(process.pid, await process.exitCode, await output, await errors);
    expect('${result.stdout}${result.stderr}'.contains(master), isFalse, reason: 'the master password stays hidden');
    expect('${result.stdout}${result.stderr}'.contains(value), isFalse, reason: 'entry values stay hidden');
    return result;
  }

  // Harm: a missing entry starts a host stop with an incomplete or empty secret feed.
  for (final missing in entries) {
    test('a missing $missing is named before any host stop starts', () async {
      final result = await run(present: entries.where((entry) => entry != missing).toList());
      expect(await File(observation).exists(), isFalse, reason: 'no host command before all entries exist');
      expect(result.exitCode, isNot(0));
      expect(result.stdout, isEmpty);
      expect(result.stderr, contains(missing));
      expect(result.stderr, contains('Add it in KeePassXC'));
    });
  }

  // Harm: an unreadable file or value starts the host with no valid feed.
  for (final failure in ['list', 'read']) {
    test('a failed $failure starts no host stop', () async {
      final result = await run(failure: failure);
      expect(result.exitCode, isNot(0));
      expect(await File(observation).exists(), isFalse);
      expect(result.stdout, isEmpty);
    });
  }

  // Harm: an existing but unusable value starts a stop and is misreported as an absent entry.
  for (final entry in entries) {
    for (final failure in ['empty', 'unreadable']) {
      test('an $failure $entry names the problem and remedy before any SSH', () async {
        final result = await run(
          values: {if (failure == 'empty') entry: ''},
          unreadable: failure == 'unreadable' ? entry : null,
        );
        expect(result.exitCode, isNot(0));
        expect(await File(observation).exists(), isFalse);
        expect(result.stdout, isEmpty);
        expect(result.stderr, contains(entry));
        expect(result.stderr, contains(failure == 'empty' ? 'empty' : 'could not be read'));
        expect(result.stderr, contains('KeePassXC'));
        expect(result.stderr, isNot(contains('has no entry')));
      });
    }
  }

  // Harm: a command preceding the secret pipe changes the host before bad input is refused.
  for (final prelude in ['matrix-token', 'drive', 'forge-certificate']) {
    test('bad base64 is refused before the $prelude host command', () async {
      const entry = 'projects/demo/keys/forge';
      final result = await run(act: HostAct.legacyUp, needs: ['keys', prelude], values: {entry: '%%% not base64'});
      expect(result.exitCode, isNot(0));
      expect(await File(observation).exists(), isFalse, reason: 'not even the host command preceding the pipe may run');
      expect(result.stdout, isEmpty);
      expect(result.stderr, contains(entry));
      expect(result.stderr, contains('base64'));
      expect(result.stderr, contains('KeePassXC'));
    });
  }

  // Harm: a partial or unusable kept CA reaches the host request step or is replaced as though absent.
  for (final entry in ['hosts/demo/forge-ca-key', 'hosts/demo/forge-ca']) {
    for (final failure in ['missing', 'empty', 'unreadable', 'bad base64', 'bad PEM']) {
      test('a CA entry that is $failure is refused before requesting certificates: $entry', () async {
        final values = {...caEntries};
        if (failure == 'empty') values[entry] = '';
        if (failure == 'bad base64') values[entry] = '%%%';
        if (failure == 'bad PEM') values[entry] = base64Encode(utf8.encode('invalid PEM'));
        final result = await run(
          act: HostAct.root,
          needs: ['forge-certificate'],
          present: caEntries.keys.where((key) => failure != 'missing' || key != entry).toList(),
          values: values,
          unreadable: failure == 'unreadable' ? entry : null,
        );
        expect(result.exitCode, isNot(0));
        expect(await File(observation).exists(), isFalse, reason: 'CA validation must precede the request over SSH');
        expect(result.stdout, isEmpty);
        expect(result.stderr, contains(entry));
        expect(result.stderr, contains('KeePassXC'));
        if (failure != 'missing') expect(result.stderr, isNot(contains('has no entry')));
      });
    }
  }

  // Harm: an unusable CA allows host changes before its network restriction is checked.
  test('a CA restricted to another network is refused before the host certificate request', () async {
    final certificate = await Process.start('/usr/bin/openssl', [
      'req',
      '-x509',
      '-new',
      '-key',
      '/dev/stdin',
      '-subj',
      '/CN=fixture',
      '-addext',
      'nameConstraints=critical,permitted;IP:10.73.7.0/255.255.255.0',
    ]);
    final output = certificate.stdout.transform(utf8.decoder).join();
    final errors = certificate.stderr.transform(utf8.decoder).join();
    certificate.stdin.write(utf8.decode(base64Decode(caEntries['hosts/demo/forge-ca-key']!)));
    await certificate.stdin.close();
    expect(await certificate.exitCode, 0, reason: await errors);
    final result = await run(
      act: HostAct.root,
      needs: ['forge-certificate'],
      present: caEntries.keys.toList(),
      values: {...caEntries, 'hosts/demo/forge-ca': base64Encode(utf8.encode(await output))},
    );
    expect(result.exitCode, isNot(0));
    expect(await File(observation).exists(), isFalse, reason: 'the CA must permit the chosen network before any SSH');
    expect(result.stdout, isEmpty);
    expect(result.stderr, contains('hosts/demo/forge-ca'));
    expect(result.stderr, contains('network'));
    expect(result.stderr, contains('KeePassXC'));
  });

  // Harm: the entry check consumes the only password, alters the feed, or exposes its values as arguments.
  test('one master password checks every entry and feeds exactly the requested lines', () async {
    final result = await run();
    expect(result.exitCode, 0, reason: '${result.stderr}');
    final observed = jsonDecode(await File(observation).readAsString()) as Map;
    expect(observed, {'input_matches': true, 'secret_argument': false, 'terminal': false});
    expect(result.stdout, isEmpty);
  });
}
