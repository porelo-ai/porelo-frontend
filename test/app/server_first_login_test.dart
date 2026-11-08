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
    String acl(String rules, {String flags = 'PAI'}) => 'porelo-first-login-x\r\nD:$flags$rules\r\n';

    test('of the account, SYSTEM and Administrators, none inherited, lets nobody else at it', () {
      expect(foreignToWindowsPin(acl('(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)(A;OICI;FA;;;$me)'), me), isEmpty);
      expect(
        foreignToWindowsPin(acl('(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)(A;OICI;FA;;;LA)'), 'S-1-5-21-111-222-333-500'),
        isEmpty,
        reason: 'the machine\'s own Administrator is written LA',
      );
    });

    test('naming Users, Everyone or another person is refused', () {
      for (final other in ['BU', 'WD', 'S-1-5-21-111-222-333-1002']) {
        expect(foreignToWindowsPin(acl('(A;OICI;FA;;;$me)(A;OICI;FR;;;$other)'), me), ['another account: $other']);
      }
      expect(foreignToWindowsPin(acl('(A;OICI;FA;;;LA)'), me), [
        'no rule for the current account',
        'another account: LA',
      ], reason: 'LA is another account unless it is the current one');
    });

    test('with a rule inherited, or inheritance not cut, is refused', () {
      expect(foreignToWindowsPin(acl('(A;OICI;FA;;;$me)(A;OICIID;FA;;;SY)'), me), ['inherited: SY']);
      expect(foreignToWindowsPin(acl('(A;OICI;FA;;;$me)', flags: 'AI'), me), ['inheritance not cut']);
    });

    test('without a rule for the account, or with none read, is refused', () {
      expect(foreignToWindowsPin(acl('(A;OICI;FA;;;SY)'), me), ['no rule for the current account']);
      expect(foreignToWindowsPin('', me), ['no DACL read']);
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
  final who = await Process.run('whoami', ['/user', '/fo', 'csv', '/nh']);
  final me = RegExp(r'"(S-1-[0-9-]+)"').firstMatch('${who.stdout}')?.group(1);
  expect(me, isNotNull, reason: 'whoami names the current account: ${who.stdout} ${who.stderr}');
  final saved = File(
    '${folder.parent.path}${Platform.pathSeparator}${folder.uri.pathSegments.lastWhere((each) => each.isNotEmpty)}.acl',
  );
  addTearDown(() async {
    if (await saved.exists()) await saved.delete();
  });
  final save = await Process.run('icacls', [folder.path, '/save', saved.path]);
  expect(save.exitCode, 0, reason: 'icacls saves the pin folder\'s ACL: ${save.stdout} ${save.stderr}');
  // icacls saves its name and its SDDL in UTF-16LE.
  final bytes = await saved.readAsBytes();
  final sddl = String.fromCharCodes([for (var at = 0; at + 1 < bytes.length; at += 2) bytes[at] | bytes[at + 1] << 8]);
  expect(foreignToWindowsPin(sddl, me!), isEmpty, reason: 'the pin folder\'s ACL, for $me: $sddl');
}

/// SYSTEM and the Administrators group, who can take any file of the account anyway.
const _windowsAboveTheAccount = {'SY', 'S-1-5-18', 'BA', 'S-1-5-32-544'};

/// What in a Windows ACL, as `icacls /save` writes its SDDL, lets anyone but the account [me] at the pin: inheritance not
/// cut, inherited rules, and rules for any other account, such as Users or Everyone. `LA` is the machine's own
/// Administrator account, so it is [me] where [me] is that account.
List<String> foreignToWindowsPin(String sddl, String me) {
  final dacl = RegExp(r'D:([A-Z]*)((?:\([^)]*\))*)').firstMatch(sddl);
  if (dacl == null) return ['no DACL read'];
  final rules = [for (final each in RegExp(r'\(([^)]*)\)').allMatches(dacl.group(2)!)) each.group(1)!.split(';')];
  bool isMe(String sid) => sid == me || (sid == 'LA' && me.endsWith('-500'));
  return [
    if (!dacl.group(1)!.contains('P')) 'inheritance not cut',
    if (!rules.any((rule) => rule.length > 5 && rule[0] == 'A' && isMe(rule[5]))) 'no rule for the current account',
    for (final rule in rules)
      if (rule.length < 6)
        'unreadable rule: ${rule.join(';')}'
      else if (rule[1].contains('ID'))
        'inherited: ${rule[5]}'
      else if (!isMe(rule[5]) && !_windowsAboveTheAccount.contains(rule[5]))
        'another account: ${rule[5]}',
  ];
}
