import 'dart:async';
import 'dart:io';

import 'machines.dart';

/// A forward held open for one agent login, taken down when the login's terminal goes.
abstract interface class HeldForward {
  /// Takes it down. Only what was raised here is ever taken down.
  Future<void> close();
}

/// Why a login's redirect could not be forwarded, in a sentence somebody can act on.
class ForwardRefused implements Exception {
  /// Constructor taking the sentence.
  const ForwardRefused(this.words);

  /// Why, in a sentence a person can act on.
  final String words;

  @override
  String toString() => words;
}

/// Raises the forward a login's redirect needs: [port] here to the same port on [machine].
/// Injectable, so the frame is judged without a process.
typedef RaiseLoginForward = Future<HeldForward> Function(Machine machine, int port);

/// What raises one: ssh, as every other forward here.
RaiseLoginForward raiseLoginForward = _withSsh;

/// The forwards raised through [raiseForward] and not yet taken down.
final Set<HeldForward> _held = <HeldForward>{};

/// Raises a forward as [raiseLoginForward] does, and **keeps track of it**, so that the window
/// closing takes it down with everything else this interface raised: an ssh left running forwards
/// a port of the machine to nobody, and holds it against the next one.
Future<HeldForward> raiseForward(Machine machine, int port) async {
  final tracked = _Tracked(await raiseLoginForward(machine, port));
  _held.add(tracked);
  return tracked;
}

/// Takes down every forward raised through [raiseForward] that is still held. Called when the window
/// closes; only what this interface raised is in there.
Future<void> letGoOfTheForwards() async {
  for (final each in _held.toList()) {
    await each.close();
  }
}

class _Tracked implements HeldForward {
  _Tracked(this._forward);

  final HeldForward _forward;

  @override
  Future<void> close() async {
    if (!_held.remove(this)) return;
    await _forward.close();
  }
}

/// **The same number on both ends**, because the redirect names it: a browser sent to
/// `localhost:<port>` has to find the login's listener there. A machine whose socket is this
/// computer's own needs nothing — the redirect already lands on the listener.
Future<HeldForward> _withSsh(Machine machine, int port) async {
  if (machine.host.startsWith('-')) throw const ForwardRefused('An ssh host must not start with a dash.');
  if (!machine.needsATunnel) return const _Nothing();
  // Asked before, because ssh with ExitOnForwardFailure says only that it failed.
  try {
    final taken = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    await taken.close();
  } on SocketException {
    throw ForwardRefused(
      'Port $port is already in use on this computer, so the browser’s answer '
      'could not reach ${machine.name}. Close what uses it and try again.',
    );
  }
  final command = loginForwardCommand(machine, port);
  final ssh = await Process.start(command.first, command.skip(1).toList());

  final said = ssh.stderr.transform(const SystemEncoding().decoder).join();
  // Proven by connecting through it, never by ssh staying up: the login's listener answers.
  for (var tries = 0; tries < 50; tries++) {
    final exited = await ssh.exitCode.timeout(const Duration(milliseconds: 100), onTimeout: () => -1);
    if (exited != -1) {
      final words = (await said).trim();
      throw ForwardRefused(
        'The browser’s answer could not be forwarded to ${machine.name}: '
        '${words.isEmpty ? 'ssh ended with $exited' : words}',
      );
    }
    try {
      final through = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: const Duration(milliseconds: 200),
      );
      through.destroy();
      return _Ssh(ssh);
    } on SocketException {
      // Not yet: ssh binds, then the login on the far end is asked.
    }
  }
  ssh.kill();
  throw ForwardRefused('Nothing on ${machine.name} answered on port $port for the browser’s answer.');
}

class _Ssh implements HeldForward {
  _Ssh(this._process);

  final Process _process;

  @override
  Future<void> close() async => _process.kill();
}

class _Nothing implements HeldForward {
  const _Nothing();

  @override
  Future<void> close() async {}
}

/// The reply forward, sharing the login terminal's destination and host-key policy.
List<String> loginForwardCommand(Machine machine, int port) => <String>[
  openSsh('ssh'),
  ...machine.loginSshOptions,
  '-N',
  if (machine.loginSshOptions.isEmpty) ...<String>[
    '-o',
    'BatchMode=yes',
    // Never through the person's master, where the forward would outlive this process.
    '-o',
    'ControlMaster=no',
    '-o',
    'ControlPath=none',
  ],
  '-o',
  'ExitOnForwardFailure=yes',
  '-L',
  '$port:localhost:$port',
  machine.host,
];
