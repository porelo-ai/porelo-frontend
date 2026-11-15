import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/desk.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/app/ssh_console.dart';
import 'package:porelo_host/porelo_host.dart' show HostCardSsh;

import '../support/organization_fixtures.dart';

const _key = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

/// A machine an organization's card names, reached by the card's ssh config.
final _card = Machine.fromHostCard(
  HostCardSsh(
    name: 'orchard',
    address: 'orchard.example.org',
    sshPort: 22,
    hostKey: _key,
    login: 'hana',
    publicKey: _key,
  ),
  socketPath: '/tmp/orchard.sock',
  sshConfig: '/tmp/orchard.config',
);

/// A machine added by its address, reached over ssh as its account.
const _byAddress = Machine(
  name: 'vm',
  socketPath: '/tmp/vm.sock',
  host: 'alice@vm.example.org',
  remoteSocket: '/run/user/1000/porelo/porelod.sock',
);

void main() {
  // Harm: a console on this computer or in WSL opens ssh to nowhere, or to a machine the page does not name.
  test('a console is offered for a machine reached over ssh, and not for this computer or WSL', () {
    expect(sshConsoleOffered(_card), isTrue);
    expect(sshConsoleOffered(_byAddress), isTrue);
    expect(sshConsoleOffered(Machine.local()), isFalse);
    expect(
      sshConsoleOffered(const Machine(name: 'ubuntu', socketPath: '', kind: 'wsl', distribution: 'Ubuntu')),
      isFalse,
    );
    expect(sshConsoleOffered(const Machine(name: 'forwarded', socketPath: '/tmp/forwarded.sock')), isFalse);
  });

  group('on Linux', () {
    late Desk before;
    setUp(() {
      before = desk;
      desk = Desk.of('linux', const {});
    });
    tearDown(() => desk = before);

    // Harm: the console logs in by a key file, asks a password in the window, trusts a key the machine was not
    // pinned with, or opens a connection of its own beside the card's master.
    test("a card's console runs ssh by the card's config through its master, a terminal and its host alone", () {
      expect(sshConsoleCommand(_card), [
        'ssh',
        '-F',
        '/tmp/orchard.config',
        '-o',
        'ControlMaster=no',
        '-o',
        'ProxyCommand=false',
        '-t',
        'orchard',
      ]);
    });

    // Harm: a machine added by its address gets options of the window's own that its other commands do not take.
    test("a machine added by its address runs plain ssh to its account, as the window's other commands to it", () {
      expect(sshConsoleCommand(_byAddress), ['ssh', '-t', 'alice@vm.example.org']);
    });
  });

  // Harm: on Windows the console runs another ssh than the system's OpenSSH, or waits on a control master Windows'
  // OpenSSH does not hold.
  test("on Windows a card's console runs the system's OpenSSH by the card's config, with a connection of its own", () {
    final before = desk;
    desk = Desk.of('windows', const {'SystemRoot': r'D:\Windows'});
    addTearDown(() => desk = before);
    expect(sshConsoleCommand(_card), [
      r'D:\Windows\System32\OpenSSH\ssh.exe',
      '-F',
      '/tmp/orchard.config',
      '-t',
      'orchard',
    ]);
  });

  // Harm: an entry the window cannot reach opens a console by a key file, an unverified host or no config at all.
  group('an entry the window cannot reach opens no console', () {
    final card = _card.hostCard!;
    for (final (what, machine) in [
      (
        'an obsolete host entry with a key file',
        const Machine(
          name: 'old',
          socketPath: '/tmp/old.sock',
          host: 'old.example.org',
          remoteSocket: '/run/porelo/porelod.sock',
          kind: 'host',
          identity: '/keys/old',
        ),
      ),
      (
        "a card's entry whose host is not the card's",
        Machine(
          name: 'orchard',
          socketPath: '/tmp/orchard.sock',
          host: 'elsewhere.example.org',
          remoteSocket: card.daemonSocket,
          kind: 'host',
          hostCard: card,
          sshConfig: '/tmp/orchard.config',
        ),
      ),
      ("a card's entry without its config", Machine.fromHostCard(card, socketPath: '/tmp/orchard.sock', sshConfig: '')),
      (
        'a host entry naming no project',
        const Machine(
          name: 'bare',
          socketPath: '/tmp/bare.sock',
          host: 'bare.example.org',
          remoteSocket: '/run/porelo/porelod.sock',
          kind: 'host',
        ),
      ),
    ]) {
      test(what, () {
        expect(machine.whyNotReachableHere, isNotNull, reason: 'the page says the same words');
        expect(() => sshConsoleCommand(machine), throwsStateError);
        expect(sshConsoleRefusal(machine), isNotNull, reason: 'the page greys its button with these words');
      });
    }

    // Harm: a configuration that cannot be built escapes as another error than the one the console's caller says.
    test('a host project whose config cannot be built', () {
      const machine = Machine(
        name: 'odd',
        socketPath: '/tmp/odd.sock',
        host: 'odd.example.org',
        remoteSocket: '/run/porelo/porelod.sock',
        kind: 'host',
        hostProject: 'not a name',
      );
      expect(() => sshConsoleCommand(machine), throwsStateError);
      expect(sshConsoleRefusal(machine), contains('SSH configuration could not be found'));
    });
  });

  // Harm: a person root takes no key from is offered a root shell, or a person root takes one from is not; root takes
  // the card keys of the persons listed as that machine's admins, and an Organization Admin not listed takes none.
  group('the root switch', () {
    OrganizationView reading(
      String me, {
      List<String> admins = const ['hana'],
      List<String>? organizationAdmins,
      bool stale = false,
    }) => organizationFor(
      me,
      host: OrganizationHost(name: 'orchard', admins: admins),
      organizationAdmins: organizationAdmins,
      stale: stale,
    );

    test("is offered to a person listed as that machine's admin", () {
      expect(rootConsoleOffered(_card, reading('hana')), isTrue);
    });

    test('is offered to a listed admin on a stale reading too, which still names who root takes', () {
      expect(rootConsoleOffered(_card, reading('hana', stale: true)), isTrue);
    });

    for (final (what, view) in [
      ("an owner not listed, who does the Organization Admins' work", reading('olive')),
      ('an Organization Admin not listed', reading('olive', organizationAdmins: ['olive'])),
      ('a project member not listed', reading('mia')),
      ('a listed admin whose card is revoked', reading('rex', admins: ['rex'])),
      ('a person listed on another machine only', organizationFor('hana')),
    ]) {
      test('is not offered to $what', () {
        expect(rootConsoleOffered(_card, view), isFalse);
      });
    }

    test('is not offered without a reading, or for a machine no card names', () {
      expect(rootConsoleOffered(_card, null), isFalse);
      expect(rootConsoleOffered(_byAddress, reading('hana')), isFalse);
      expect(() => sshConsoleCommand(_byAddress, asRoot: true), throwsStateError);
    });
  });

  // Harm: the root console takes options the person's own does not, a key file or a password among them, or on Linux
  // rides the person's open master, whose path does not name the login, and opens their shell instead of root's.
  group("the root console's line", () {
    late Desk before;
    setUp(() => before = desk);
    tearDown(() => desk = before);

    test('on Linux differs from the own line only in the login and a connection of its own', () {
      desk = Desk.of('linux', const {});
      final own = sshConsoleCommand(_card);
      final root = sshConsoleCommand(_card, asRoot: true);
      expect(root, [
        'ssh',
        '-F',
        '/tmp/orchard.config',
        '-o',
        'ControlMaster=no',
        '-o',
        'ControlPath=none',
        '-o',
        'ProxyCommand=none',
        '-t',
        'root@orchard',
      ]);
      expect(own.where((each) => !root.contains(each)), ['ProxyCommand=false', 'orchard']);
    });

    test('on Windows differs from the own line only in the login', () {
      desk = Desk.of('windows', const {'SystemRoot': r'D:\Windows'});
      final own = sshConsoleCommand(_card);
      expect(sshConsoleCommand(_card, asRoot: true), [...own.take(own.length - 1), 'root@orchard']);
    });
  });

  // Harm: a host that reads as an option makes ssh run what it names.
  test('a host that starts with a dash opens no console', () {
    const dashed = Machine(name: 'odd', socketPath: '/tmp/odd.sock', host: '-oProxyCommand=x', remoteSocket: '/s');
    expect(() => sshConsoleCommand(dashed), throwsStateError);
    expect(() => sshConsoleCommand(Machine.local()), throwsStateError);
  });
}
