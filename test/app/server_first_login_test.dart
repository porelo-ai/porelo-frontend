import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/server_first_login.dart';

const _key = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl';

void main() {
  // Harm: the first login trusts another key than the one compared, or writes it into the person's own known_hosts.
  test('the first login trusts the compared key alone, from its own pin', () async {
    final pin = await ComparedKeyPin.make('192.0.2.7', _key);
    addTearDown(pin.dispose);
    expect(await pin.file.readAsString(), '192.0.2.7 $_key\n');
    await _expectTheOwnersAlone(pin.file.parent);
    final command = firstLoginCommand(pin: pin.file.path, user: 'ubuntu', address: '192.0.2.7');
    final options = <String>[
      for (var at = 0; at < command.length - 1; at++)
        if (command[at] == '-o') command[at + 1],
    ];
    expect(options, contains('StrictHostKeyChecking=yes'));
    expect(options, contains('UserKnownHostsFile="${pin.file.path}"'));
    expect(options, contains('GlobalKnownHostsFile=none'));
    expect(options, contains('UpdateHostKeys=no'));
    expect(options, contains('ForwardAgent=no'));
    expect(command.last, 'ubuntu@192.0.2.7');
    await pin.dispose();
    expect(Directory(pin.file.parent.path).existsSync(), isFalse, reason: 'the pin goes with its folder');
  });

  // Harm: root still held by the provider's line reads as open or as no answer, and the person skips the bootstrap.
  group('a root login', () {
    test('answered by the provider\'s line and exit 142 says the bootstrap line has not run', () {
      final login = readRootLogin(142, 'Please login as the user "ubuntu" rather than the user "root".\n', '');
      expect(login.state, RootLoginState.providersLine);
      expect(login.words, contains('The bootstrap line has not run'));
      expect(login.words, contains('Please login as the user "ubuntu"'));
    });

    test('that ends 0 with no provider\'s line is open', () {
      expect(readRootLogin(0, '', '').state, RootLoginState.open);
    });

    test('refused with the card key says so', () {
      expect(readRootLogin(255, '', 'root@192.0.2.7: Permission denied (publickey).\n').state, RootLoginState.refused);
    });

    test('with another host key goes back to the key', () {
      final login = readRootLogin(255, '', 'Host key verification failed.\n');
      expect(login.state, RootLoginState.noAnswer);
      expect(login.words, contains('another SSH host key'));
    });
  });
}

/// Linux keeps the folder at `0700`; Windows reports no POSIX mode, and keeps it by an ACL that holds the current
/// user's full control alone, with inheritance cut.
Future<void> _expectTheOwnersAlone(Directory folder) async {
  if (!Platform.isWindows) {
    expect((await folder.stat()).mode & 0x1ff, 0x1c0, reason: 'the pin folder is the owner\'s alone');
    return;
  }
  final user = '${(await Process.run('whoami', const <String>[])).stdout}'.trim().toLowerCase();
  final acl = await Process.run('icacls', [folder.path]);
  expect(acl.exitCode, 0, reason: 'icacls reads the pin folder: ${acl.stderr}');
  final entries = '${acl.stdout}'.split(RegExp(r'\r?\n')).where((line) => line.contains(':(')).toList();
  expect(entries, hasLength(1), reason: 'the pin folder grants one account alone: ${acl.stdout}');
  expect(entries.single.toLowerCase(), contains('$user:(oi)(ci)(f)'), reason: 'that account is the current user');
  expect(entries.single, isNot(contains('(I)')), reason: 'nothing is inherited from the temporary folder');
}
