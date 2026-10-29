import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:porelo_host/porelo_host.dart';
import 'package:porelo_frontend/src/app/host_stop_feed.dart';

/// The stop's terminal when the host takes its secrets from the person's file, on standard input.
void main() {
  List<String> command({
    List<String> needs = const ['vault-new', 'wireguard'],
    List<String> keys = const [],
    String email = '',
    String ssh = '/usr/bin/ssh',
    String host = 'ubuntu@203.0.113.7',
    String? driveHost = 'porelo@203.0.113.7',
  }) => hostStopFeedCommand(
    secretsFile: '/home/person/Porelo/secrets.kdbx',
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
  test('the forge\'s request is asked of the host before the file is opened, and only where it waits', () {
    final script = command(needs: ['forge-certificate']).last;
    final asked = script.indexOf('porelo-host-stop --request');
    expect(asked, greaterThan(-1));
    expect(asked, lessThan(script.indexOf('/usr/bin/stty -echo')), reason: 'before the file is opened');
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
      script.indexOf('/usr/bin/stty -echo'),
      greaterThan(script.indexOf(' -t ')),
      // ssh hands this terminal's modes to the far end's: with echo off there, the e-mail typed would not show.
      reason: 'echo kept for the drive\'s login',
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
      home = await Directory(Platform.environment['HOME']!).createTemp('porelo-stop-feed-test-');
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
  }, skip: Platform.isWindows ? 'the feed runs bash, which only Linux has here' : null);

  // Against the real keepassxc-cli: what reaches the far end is the lines and nothing else.
  // Harm: a Tresorit login that failed, and the secrets piped after it all the same.
  test('a drive login that fails ends the terminal before the file is opened', () async {
    final home = await Directory(Platform.environment['HOME']!).createTemp('porelo-stop-feed-test-');
    addTearDown(() => home.delete(recursive: true));
    final calls = path.join(home.path, 'calls');
    final fakeSsh = await File(path.join(home.path, 'ssh')).writeAsString('#!/bin/sh\necho "\$@" >> $calls\nexit 3\n');
    await Process.run('chmod', ['700', fakeSsh.path]);
    final run = command(needs: ['drive', 'vault'], email: 'me@example.org', ssh: fakeSsh.path);
    final process = await Process.start(run.first, run.skip(1).toList());
    await process.stdin.close();
    await process.stdout.drain<void>();
    await process.stderr.drain<void>();
    expect(await process.exitCode, 3, reason: 'the login\'s own exit');
    expect(await File(calls).readAsLines(), hasLength(1), reason: 'no second ssh, no pipe');
  }, skip: Platform.isWindows ? 'the feed runs bash, which only Linux has here' : null);

  group('run', () {
    final cli = Platform.environment['KEEPASSXC_CLI'] ?? SecretsFile.keepassxcCli;
    final skip = File(cli).existsSync() ? null : 'needs keepassxc-cli at $cli (set KEEPASSXC_CLI) and wg';

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
