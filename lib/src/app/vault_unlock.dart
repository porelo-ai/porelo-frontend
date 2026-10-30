import 'connections.dart';
import 'machines.dart';

/// The line that opens [machine]'s vault in a terminal, or null where nothing here can reach it.
///
/// **The passphrase goes keyboard → terminal → ssh → porelo**, and this program never holds it: a
/// daemon has no terminal to take one at, so the terminal is the machine's own `porelo`. `ssh -t`
/// for a machine this interface reaches over ssh; the local daemon's own `porelo` for this one. A
/// socket somebody else forwarded has no host behind it, and running `porelo` here would open a
/// different vault from the one that machine uses — so it is not offered at all. A refused passphrase is asked
/// again in that terminal, three attempts at most.
///
/// A host vault is opened by Core through the shared SSH tunnel.
List<String>? unlockCommandFor(Machine machine) {
  if (machine.kind == 'host') return null;
  return onTheMachine(machine, const <String>['sh', '-c', _unlockAskingAgain], terminal: true);
}

/// `porelo vault unlock`, asked again after a refused passphrase (porelo's 70), three attempts at most; any other
/// exit ends it with its own code.
const _unlockAskingAgain = r'''for attempt in 1 2 3; do
  porelo vault unlock
  code=$?
  [ "$code" -eq 70 ] || exit "$code"
  if [ "$attempt" -lt 3 ]; then
    printf '%s\n' 'The passphrase was refused. Try again.'
  fi
done
printf '%s\n' 'The passphrase was refused three times.' >&2
exit 70''';

/// The line that makes [machine]'s vault in a terminal — a passphrase chosen and typed twice there,
/// never here — or null where nothing here can reach that machine's own `porelo`. Porelo leaves a
/// vault it has just made open, so a device can be enrolled straight afterwards.
/// A rented server's vault is made by its setup, from the secrets file, never here.
List<String>? makeCommandFor(Machine machine) =>
    machine.kind == 'host' ? null : onTheMachine(machine, const <String>['porelo', 'vault', 'init'], terminal: true);
