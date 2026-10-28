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
    expect(script, contains("'hosts/checkout/vault-passphrase'"));
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
    expect(script, contains("'hosts/checkout/keys/forge'"));
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
    expect(both, contains('--stdin vault matrix-token'));
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

  // Harm: the host's token read wrongly, sent as more than one line, or left on this computer once it is sent.
  test('the stand-in host gets exactly its matrix token line, and the admission is gone after', () async {
    final home = await Directory(Platform.environment['HOME']!).createTemp('porelo-stop-feed-test-');
    addTearDown(() => home.delete(recursive: true));
    final got = path.join(home.path, 'got');
    final into = path.join(home.path, 'into');
    final fakeSsh = await File(path.join(home.path, 'ssh')).writeAsString(
      '#!/bin/sh\n'
      'case "\$*" in *hostname*) echo checkout-host;; *porelo-host-stop*) cat > $got;; esac\n',
    );
    final fakePorelo = await File(path.join(home.path, 'porelo')).writeAsString(
      '#!/bin/sh\n'
      // Takes any machine's name, as a real Porelo might: the check of the name is the script's own.
      '[ "\$1 \$2 \$3 \$5" = "talk admit checkout --into" ] || exit 9\n'
      'echo "\$6" > $into\n'
      'printf \'{"admission":{"machine":"checkout-host"},"secrets":{"registration_token":"tok en"}}\' > "\$6"\n',
    );
    for (final file in [fakeSsh, fakePorelo]) {
      await Process.run('chmod', ['700', file.path]);
    }
    final run = command(needs: ['matrix-token'], ssh: fakeSsh.path);
    final script = run.last.replaceAll('/usr/bin/porelo talk', '${fakePorelo.path} talk');
    final process = await Process.start(run.first, [...run.skip(1).take(run.length - 2), script]);
    await process.stdin.close();
    final said = await process.stderr.transform(utf8.decoder).join();
    await process.stdout.drain<void>();
    expect(await process.exitCode, 0, reason: said);
    expect(await File(got).readAsString(), 'matrix-token ${base64.encode(utf8.encode('tok en'))}\n');
    final admission = File((await File(into).readAsString()).trim());
    expect(admission.existsSync(), isFalse, reason: 'the admission goes with the terminal');
    expect(admission.parent.existsSync(), isFalse);

    // A host whose name reads as an option, or holds what a shell would split, is let in nowhere.
    for (final name in ['-rf', 'a b', r'x$y']) {
      for (final left in [got, into]) {
        if (File(left).existsSync()) File(left).deleteSync();
      }
      await fakeSsh.writeAsString(
        '#!/bin/sh\n'
        "case \"\$*\" in *hostname*) printf '%s\\n' '$name';; *porelo-host-stop*) cat > $got;; esac\n",
      );
      final refused = await Process.start(run.first, [...run.skip(1).take(run.length - 2), script]);
      await refused.stdin.close();
      await refused.stdout.drain<void>();
      await refused.stderr.drain<void>();
      expect(await refused.exitCode, isNot(0), reason: name);
      expect(File(got).existsSync(), isFalse, reason: 'nothing sent for $name');
      expect(File(into).existsSync(), isFalse, reason: 'this computer\'s Porelo not asked for $name');
    }
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
      final home = await Directory(Platform.environment['HOME']!).createTemp('porelo-stop-feed-test-');
      addTearDown(() => home.delete(recursive: true));
      final kdbx = path.join(home.path, 'secrets.kdbx');
      final made = await Process.start('bash', [
        '-c',
        SecretsFile(
          kdbx,
          cli: cli,
        ).prepareHost(project: 'checkout', create: true, publicKeyOut: path.join(home.path, 'k.pub')),
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
}
