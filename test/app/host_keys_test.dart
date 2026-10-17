import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_keys.dart';

/// OpenSSH as far as these checks ask it: `ssh -G`, `ssh-keygen -F` and `-l`, `ssh-keyscan`.
class _Ssh {
  _Ssh({this.config = 'hostname build.example.test\nport 22\nuserknownhostsfile ~/.ssh/known_hosts ~/.ssh/known_hosts2\n'});

  final String config;

  /// Which `known_hosts` files know which hosts.
  final Map<String, Set<String>> knows = <String, Set<String>>{};

  /// The key those files hold for them.
  String knownKey = 'ssh-ed25519 AAAAC3Nza';

  String scanned = '|1|abc= ssh-ed25519 AAAAC3Nza\n# a comment ssh-keyscan prints\n';
  final List<List<String>> ran = <List<String>>[];
  String? given;

  Future<ProcessResult> run(List<String> command, {String? input}) async {
    ran.add(command);
    ProcessResult answer(int code, [String out = '', String err = '']) => ProcessResult(0, code, out, err);
    switch (command) {
      case ['ssh', '-G', _]:
        return answer(0, config);
      case ['ssh-keygen', '-F', final host, '-f', final file]:
        final found = (knows[file] ?? const <String>{}).contains(host);
        return answer(found ? 0 : 1, found ? '# Host $host found: line 3\n|1|old= $knownKey\n' : '');
      case ['ssh-keyscan', ...]:
        return answer(0, scanned);
      case ['ssh-keygen', '-l', '-f', '-']:
        given = input;
        return answer(0, '256 SHA256:fingerprint build.example.test (ED25519)\n');
      default:
        return answer(0);
    }
  }
}

void main() {
  test('an unknown host is scanned on the port ssh will use, and its fingerprints are shown', () async {
    final ssh = _Ssh();

    final check = await SshHostKeys(run: ssh.run, home: '/home/somebody').check('alice@build');

    expect(check.known, isFalse);
    expect(check.host, 'build.example.test', reason: 'the alias was not resolved');
    expect(ssh.ran, anyElement(equals(<String>['ssh-keyscan', '-T', '10', '-H', '-p', '22', 'build.example.test'])));
    expect(check.scanned, <String>['|1|abc= ssh-ed25519 AAAAC3Nza'], reason: 'a comment would be written');
    expect(check.fingerprints.single, contains('SHA256:fingerprint'));
    expect(ssh.given, contains('ssh-ed25519 AAAAC3Nza'), reason: 'the fingerprints are of other keys');
  });

  test('a host known in any of the files ssh reads, with the key it shows, is not asked about', () async {
    final ssh = _Ssh()..knows['/home/somebody/.ssh/known_hosts2'] = <String>{'build.example.test'};

    final check = await SshHostKeys(run: ssh.run, home: '/home/somebody').check('build');

    expect(check.known, isTrue);
    expect(check.changed, isFalse);
  });

  // A rented server's address given to a new machine: the old key is known, and it is not this one.
  test('a known host showing another key is said to have changed, and nothing is decided', () async {
    final ssh = _Ssh()
      ..knows['/home/somebody/.ssh/known_hosts'] = <String>{'build.example.test'}
      ..knownKey = 'ssh-ed25519 AAAAoldmachine';

    final check = await SshHostKeys(run: ssh.run, home: '/home/somebody').check('build');

    expect(check.known, isFalse);
    expect(check.changed, isTrue);
    expect(check.knownIn, <String>['/home/somebody/.ssh/known_hosts']);
    expect(check.fingerprints.single, contains('SHA256:fingerprint'));
  });

  test('off port 22 the host is named the way known_hosts names it', () async {
    final ssh = _Ssh(config: 'hostname 203.0.113.10\nport 2222\nuserknownhostsfile ~/.ssh/known_hosts\n')
      ..knows['/home/somebody/.ssh/known_hosts'] = <String>{'203.0.113.10'};

    final check = await SshHostKeys(run: ssh.run, home: '/home/somebody').check('rented');

    expect(check.host, '[203.0.113.10]:2222');
    expect(check.known, isFalse, reason: 'the key for port 22 stood in for port 2222');
    expect(ssh.ran, anyElement(equals(<String>['ssh-keyscan', '-T', '10', '-H', '-p', '2222', '203.0.113.10'])));
  });

  test('a host that offers no key says so, and there is nothing to trust', () async {
    final ssh = _Ssh()..scanned = '';

    final check = await SshHostKeys(run: ssh.run, home: '/home/somebody').check('build');

    expect(check.problem, contains('No host key came back'));
    expect(check.scanned, isEmpty);
  });

  test('accepting appends exactly what was scanned, owner-only', () async {
    final home = Directory.systemTemp.createTempSync('host-keys-');
    addTearDown(() => home.deleteSync(recursive: true));
    File('${(Directory('${home.path}/.ssh')..createSync()).path}/known_hosts')
        .writeAsStringSync('existing line\n');

    await SshHostKeys(home: home.path).accept(const HostKeyCheck(
      destination: 'build',
      host: 'build.example.test',
      known: false,
      scanned: <String>['|1|abc= ssh-ed25519 AAAAC3Nza'],
    ));

    expect(File('${home.path}/.ssh/known_hosts').readAsStringSync(),
        'existing line\n|1|abc= ssh-ed25519 AAAAC3Nza\n');
  });

  // Linux only: it reads the file's mode, which Windows does not keep.
  test('a first known_hosts is made owner-only', () async {
    final home = Directory.systemTemp.createTempSync('host-keys-');
    addTearDown(() => home.deleteSync(recursive: true));

    await SshHostKeys(home: home.path).accept(const HostKeyCheck(
      destination: 'build',
      host: 'build.example.test',
      known: false,
      scanned: <String>['|1|abc= ssh-ed25519 AAAAC3Nza'],
    ));

    expect(FileStat.statSync('${home.path}/.ssh').mode & 0x1FF, 0x1C0); // 700
    expect(FileStat.statSync('${home.path}/.ssh/known_hosts').mode & 0x1FF, 0x180); // 600
  }, tags: 'linux');

  test('replacing a changed key takes the old one out first, then keeps the new one', () async {
    final home = Directory.systemTemp.createTempSync('host-keys-');
    addTearDown(() => home.deleteSync(recursive: true));
    final file = File('${(Directory('${home.path}/.ssh')..createSync()).path}/known_hosts')
      ..writeAsStringSync('203.0.113.10 ssh-ed25519 AAAAoldmachine\nother.example ssh-ed25519 AAAAkeep\n');

    await SshHostKeys(home: home.path).accept(HostKeyCheck(
      destination: 'root@203.0.113.10',
      host: '203.0.113.10',
      known: false,
      changed: true,
      knownIn: <String>[file.path],
      scanned: const <String>['203.0.113.10 ssh-ed25519 AAAAnewmachine'],
    ));

    final now = file.readAsStringSync();
    expect(now, isNot(contains('AAAAoldmachine')));
    expect(now, contains('other.example ssh-ed25519 AAAAkeep'), reason: 'another host was taken out');
    expect(now, contains('AAAAnewmachine'));
  });

  test('a trusted key goes where ssh will look for it, not always into ~/.ssh/known_hosts', () async {
    // A UserKnownHostsFile of its own is honored when checking, so it is where accepting writes too.
    final home = Directory.systemTemp.createTempSync('host-keys-');
    addTearDown(() => home.deleteSync(recursive: true));
    final own = '${home.path}/keys/hosts';
    final ssh = _Ssh(config: 'hostname build.example.test\nport 22\nuserknownhostsfile $own ~/.ssh/known_hosts\n');
    final keys = SshHostKeys(run: ssh.run, home: home.path);

    await keys.accept(await keys.check('build'));

    expect(File(own).readAsStringSync(), '|1|abc= ssh-ed25519 AAAAC3Nza\n');
    expect(File('${home.path}/.ssh/known_hosts').existsSync(), isFalse);
  });
}
