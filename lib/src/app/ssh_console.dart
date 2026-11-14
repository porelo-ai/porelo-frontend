import 'machines.dart';

/// Whether [machine] is reached over ssh, so a console on it is a shell on another computer: never this computer, a
/// WSL distribution, or a socket somebody else forwards.
bool sshConsoleOffered(Machine machine) => machine.needsATunnel && (machine.kind.isEmpty || machine.kind == 'host');

/// The console's command line on [machine]: ssh with exactly the options every other command to it takes, so the key
/// is the agent's and the host key the pinned one, a terminal, and the host as the machine names it.
///
/// No remote command follows the host, so the far end starts the account's own login shell.
List<String> sshConsoleCommand(Machine machine) {
  if (!sshConsoleOffered(machine)) throw StateError('${machine.name} is not reached over ssh.');
  // ssh would read such a host as an option, and an option can run a command here.
  if (machine.host.startsWith('-')) throw StateError('A machine’s ssh address must not start with a dash.');
  return [openSsh('ssh'), ...machine.loginSshOptions, '-t', machine.host];
}
