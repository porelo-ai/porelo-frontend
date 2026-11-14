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
  // What the page says of an entry it cannot reach: an obsolete key file, a card's unverified host or missing config.
  if (machine.whyNotReachableHere case final why?) throw StateError(why);
  // ssh would read such a host as an option, and an option can run a command here.
  if (machine.host.startsWith('-')) throw StateError('A machine’s ssh address must not start with a dash.');
  final card = machine.hostCard;
  if (card != null && (machine.sshConfig.isEmpty || machine.host != card.name)) {
    throw StateError("${machine.name} needs its card's own SSH configuration.");
  }
  final List<String> options;
  try {
    options = machine.loginSshOptions;
  } on FormatException catch (error) {
    throw StateError("${machine.name}'s SSH configuration could not be found: ${error.message}");
  }
  // The key is the agent's alone: an entry that would hand ssh a key file opens nothing.
  if (options.contains('-i')) throw StateError('${machine.name} names a key file, which the console never uses.');
  return [openSsh('ssh'), ...options, '-t', machine.host];
}

/// Why the console of [machine] cannot be opened, in the words [sshConsoleCommand] refuses with; null where it can.
String? sshConsoleRefusal(Machine machine) {
  try {
    sshConsoleCommand(machine);
    return null;
  } on StateError catch (refused) {
    return refused.message;
  }
}
