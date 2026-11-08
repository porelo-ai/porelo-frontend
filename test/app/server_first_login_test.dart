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

  // Harm: a pin folder another ordinary Windows account can write, so a key other than the one compared is trusted.
  group('a Windows pin folder\'s ACL', () {
    const me = 'S-1-5-21-111-222-333-1001';
    String acl(List<String> rules, {bool protected = true}) =>
        ['protected|${protected ? 'True' : 'False'}', 'me|$me', for (final rule in rules) 'rule|$rule'].join('\r\n');

    test('of the account, SYSTEM and Administrators, none inherited, lets nobody else at it', () {
      expect(
        foreignToWindowsPin(acl(['$me|False|Allow', 'S-1-5-18|False|Allow', 'S-1-5-32-544|False|Allow'])),
        isEmpty,
      );
    });

    test('naming Users, Everyone or another person is refused', () {
      for (final other in ['S-1-5-32-545', 'S-1-1-0', 'S-1-5-21-111-222-333-1002']) {
        expect(foreignToWindowsPin(acl(['$me|False|Allow', '$other|False|Allow'])), ['another account: $other']);
      }
    });

    test('with a rule inherited, or inheritance not cut, is refused', () {
      expect(foreignToWindowsPin(acl(['$me|False|Allow', 'S-1-5-18|True|Allow'])), ['inherited: S-1-5-18']);
      expect(foreignToWindowsPin(acl(['$me|False|Allow'], protected: false)), ['inheritance not cut']);
    });

    test('without a rule for the account is refused', () {
      expect(foreignToWindowsPin(acl(['S-1-5-18|False|Allow'])), ['no rule for the current account']);
    });
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

/// Linux keeps the folder at `0700`; Windows reports no POSIX mode, and keeps it by an ACL cut from inheritance.
Future<void> _expectTheOwnersAlone(Directory folder) async {
  if (!Platform.isWindows) {
    expect((await folder.stat()).mode & 0x1ff, 0x1c0, reason: 'the pin folder is the owner\'s alone');
    return;
  }
  final read = await Process.run(
    'powershell',
    [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      r'$acl = Get-Acl -LiteralPath $env:PORELO_PIN_FOLDER; '
          r'"protected|$($acl.AreAccessRulesProtected)"; '
          r'"me|$([System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value)"; '
          r'foreach ($rule in $acl.Access) { '
          r'"rule|$($rule.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value)|'
          r'$($rule.IsInherited)|$($rule.AccessControlType)" }',
    ],
    environment: {'PORELO_PIN_FOLDER': folder.path},
  );
  expect(read.exitCode, 0, reason: 'PowerShell reads the pin folder\'s ACL: ${read.stderr}');
  expect(foreignToWindowsPin('${read.stdout}'), isEmpty, reason: 'the pin folder\'s ACL: ${read.stdout}');
}

/// SYSTEM and the Administrators group, who can take any file of the account anyway.
const _windowsAboveTheAccount = {'S-1-5-18', 'S-1-5-32-544'};

/// What in a Windows ACL, as the test's PowerShell lines print it, lets anyone but the account at the pin: inherited
/// or unprotected rules, and rules for any other account, such as Users or Everyone.
List<String> foreignToWindowsPin(String lines) {
  String? me;
  bool? protected;
  final rules = <List<String>>[];
  for (final line in lines.split(RegExp(r'\r?\n')).map((each) => each.trim()).where((each) => each.isNotEmpty)) {
    final parts = line.split('|');
    switch (parts.first) {
      case 'me':
        me = parts[1];
      case 'protected':
        protected = parts[1] == 'True';
      case 'rule':
        rules.add(parts.skip(1).toList());
    }
  }
  return [
    if (me == null) 'no current account read',
    if (protected != true) 'inheritance not cut',
    if (!rules.any((rule) => rule[0] == me && rule[2] == 'Allow')) 'no rule for the current account',
    for (final rule in rules)
      if (rule[1] != 'False')
        'inherited: ${rule[0]}'
      else if (rule[0] != me && !_windowsAboveTheAccount.contains(rule[0]))
        'another account: ${rule[0]}',
  ];
}
