import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/ssh_console.dart';
import 'package:porelo_host/porelo_host.dart' show HostCardSsh;

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

  // Harm: the console logs in by a key file, asks a password in the window, or trusts a key the machine was not
  // pinned with, where the window's own commands to that machine would not.
  test("the console runs ssh with the machine's own options, a terminal and its host, and nothing else", () {
    for (final machine in [_card, _byAddress]) {
      final command = sshConsoleCommand(machine);
      expect(command, ['ssh', ...machine.loginSshOptions, '-t', machine.host]);
      expect(command, isNot(contains('-i')), reason: 'the key comes from the agent, never a file');
      expect(command.join(' '), isNot(contains('Password')), reason: 'no password reaches ssh from here');
    }
    expect(sshConsoleCommand(_card), containsAllInOrder(['-F', '/tmp/orchard.config']));
  });

  // Harm: a host that reads as an option makes ssh run what it names.
  test('a host that starts with a dash opens no console', () {
    const dashed = Machine(name: 'odd', socketPath: '/tmp/odd.sock', host: '-oProxyCommand=x', remoteSocket: '/s');
    expect(() => sshConsoleCommand(dashed), throwsStateError);
    expect(() => sshConsoleCommand(Machine.local()), throwsStateError);
  });
}
