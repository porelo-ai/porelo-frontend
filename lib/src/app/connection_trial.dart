import 'dart:async';

import 'package:porelo_frontend/client.dart';

import 'fleet_backend.dart';
import 'machines.dart';
import 'tunnel.dart';

const _tasks = 'org.fuin.porelo.Tasks1';

/// What trying a machine found, before anybody watches it.
class Trial {
  /// Constructor taking the verdict and the words for it.
  const Trial({required this.reached, required this.words, this.nothingServing = false});

  /// Whether a Porelo this build understands answered.
  final bool reached;

  /// What was found, in a sentence somebody can act on.
  final String words;

  /// Whether ssh worked and nothing served at the far end.
  ///
  /// The one failure that can be answered from here rather than only described: the host is there,
  /// the login worked, and what is missing is a daemon. Every other failure — a forward that could
  /// not be raised, a daemon serving something else — is somebody else's to fix.
  final bool nothingServing;
}

/// Tries [machine] the way watching it would, and leaves nothing running.
///
/// A forward raised here gets one of its own for the trial, on its own socket, taken down again
/// whatever was found. Connecting through it is the test: an exit code proves nothing.
Future<Trial> tryAMachine(
  Machine machine, {
  required FleetBackend Function(Machine machine) reach,
  required Tunnels tunnels,
  Duration within = const Duration(seconds: 10),
}) async {
  final why = machine.whyNotReachableHere;
  if (why != null) return Trial(reached: false, words: why);
  final target = machine.hostCard == null && machine.needsATunnel && machine.relay == null
      ? machine.withSocketPath(Machine.endpointFor('${machine.name} trial'))
      : machine;
  Tunnel? tunnel;
  try {
    if (machine.hostCard != null) {
      if (!await tunnels.raiseFor(machine)) {
        return Trial(reached: false, words: tunnels.of(machine)?.problem ?? 'The host could not be reached.');
      }
    } else if (machine.needsATunnel && machine.relay == null) {
      tunnel = await tunnels.trial(target);
      if (tunnel.state != TunnelState.up) {
        return Trial(
          reached: false,
          words: 'ssh could not raise the forward: ${tunnel.problem ?? 'it gave no reason'}',
        );
      }
    }
    final info = await reach(target).open().timeout(within);
    if (!info.interfaces.contains(_tasks)) {
      return Trial(
        reached: false,
        words:
            'It answers, but serves nothing this build understands: '
            '${info.interfaces.join(', ')}.',
      );
    }
    return Trial(reached: true, words: 'Reached ${info.product} ${info.version}.');
  } on TimeoutException {
    return Trial(reached: false, words: 'Nothing answered within ${within.inSeconds} seconds.');
  } on VarlinkException catch (refusal) {
    return Trial(reached: false, words: 'It answers, and refused: ${refusal.simpleName}.');
  } on VarlinkDisconnected catch (ex) {
    if (machine.relay?.kind == 'wsl') {
      return Trial(reached: false, words: 'Could not reach ${machine.where}: ${ex.message}');
    }
    if (machine.relay != null && (ex is! RelayDisconnected || ex.exitCode == 255 || ex.exitCode == null)) {
      final explained = await tunnels.explainRefusal(ex.message, machine.host, options: machine.loginSshOptions);
      return Trial(reached: false, words: explained ?? ex.message);
    }
    // ssh reports a missing daemon and somebody else's socket in the same words — measured
    // — and every runtime directory is owner-only, so no daemon can be asked either. The
    // login's own uid is the one thing that tells the two apart.
    if (machine.needsATunnel) {
      final typed = _uidIn(machine.remoteSocket);
      final login = typed == null ? null : await tunnels.loginUidOn(machine);
      if (typed != null && login != null && typed != login) {
        final meant = machine.remoteSocket.replaceFirst('/run/user/$typed/', '/run/user/$login/');
        // No start is offered: a daemon started for this login would still not serve that path.
        return Trial(
          reached: false,
          words:
              "That socket is in another user's runtime directory (uid $typed), but you log in "
              'as uid $login, so nothing there can be reached. Did you mean $meant?',
        );
      }
    }
    // The forward to a socket nobody serves comes up fine; only connecting through it says so.
    return Trial(
      reached: false,
      // Only a machine forwarded from here can be started from here. A socket somebody else
      // forwarded fails the same way and has no host behind it to log into.
      nothingServing: machine.needsATunnel,
      words: machine.needsATunnel
          ? '${machine.relay == null ? 'The forward came up' : 'The login worked'}, but nothing answers at ${machine.remoteSocket} on that '
                'machine. Is porelod running there, for the user you log in as? (${ex.message})'
          : 'Nothing answers at ${machine.socketPath}: ${ex.message}',
    );
  } on StateError catch (ex) {
    return Trial(reached: false, words: 'It answers, but serves nothing this build understands: ${ex.message}');
  } finally {
    await tunnel?.drop();
  }
}

/// The uid in a per-user runtime path, or null for a path that is not one.
int? _uidIn(String socket) {
  final match = RegExp(r'^/run/user/(\d+)/').firstMatch(socket);
  return match == null ? null : int.parse(match[1]!);
}

/// How many ways into [machine]'s vault there are, asked through a forward of its own taken down
/// again, or null when it could not be asked. **Zero means there is no vault yet**: a machine
/// without one answers no keyslots, and one made with a passphrase has at least that one.
Future<int?> countKeyslots(
  Machine machine, {
  required FleetBackend Function(Machine machine) reach,
  required Tunnels tunnels,
  Duration within = const Duration(seconds: 10),
}) async {
  if (machine.whyNotReachableHere != null) return null;
  final target = machine.hostCard == null && machine.needsATunnel && machine.relay == null
      ? machine.withSocketPath(Machine.endpointFor('${machine.name} vault'))
      : machine;
  Tunnel? tunnel;
  try {
    if (machine.hostCard != null) {
      if (!await tunnels.raiseFor(machine)) return null;
    } else if (machine.needsATunnel && machine.relay == null) {
      tunnel = await tunnels.trial(target);
      if (tunnel.state != TunnelState.up) return null;
    }
    final backend = reach(target);
    await backend.open().timeout(within);
    return (await backend.keyslots().timeout(within)).length;
  } on Object {
    return null;
  } finally {
    await tunnel?.drop();
  }
}
