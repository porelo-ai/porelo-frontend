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
    expect((await pin.file.parent.stat()).mode & 0x1ff, 0x1c0, reason: 'the pin folder is the owner\'s alone');
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
