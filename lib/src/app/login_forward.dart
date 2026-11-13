import 'dart:async';
import 'dart:io';

import 'package:porelo_host/porelo_host.dart' show HostCardSsh;

import 'forward_records.dart';
import 'machines.dart';
import 'own_sockets.dart';
import 'person_only_relay.dart';
import 'tunnel.dart' show Tunnel;

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

/// Starts the ssh of a login forward from its whole command line. Injectable, so a test runs a stand-in in its place.
typedef StartLoginForward = Future<Process> Function(List<String> command);

/// What starts it: the command as it is, without a shell.
StartLoginForward startLoginForward = _startIt;

Future<Process> _startIt(List<String> command) => Process.start(command.first, command.skip(1).toList());

/// The pid of the master this window started and holds for a card, by its control socket; null where it holds none.
/// Injectable, so a test's stand-in plays the master.
typedef CardMaster = int? Function(String control);

/// What names it: the card's tunnel, while its master runs.
CardMaster cardMaster = Tunnel.masterOf;

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
  // All at once: one that is slow to end, or will not, holds none of the others up.
  await Future.wait<void>([for (final each in _held.toList()) Future<void>.sync(each.close).catchError((Object _) {})]);
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
  if (machine.host.startsWith('-')) throw const ForwardRefused('A machine’s ssh address must not start with a dash.');
  if (machine.host.isEmpty) return const _Nothing();
  if (!PersonOnlyRelay.here) return _bySshAlone(machine, port);
  // The window holds the port and lets only the person in; ssh forwards a socket in a folder of the person's alone.
  final socket = loginForwardSocket(machine, port);
  // A card's machine is reached only through its master, which makes the socket: it must be the one this window holds.
  final card = machine.hostCard;
  final master = card == null ? null : cardMaster(card.controlSocket(machine.sshConfig));
  if (card != null && master == null) {
    throw ForwardRefused(
      'The browser’s answer could not be forwarded to ${machine.name}: it is not connected in this window yet.',
    );
  }
  if (!inOwnDirectory(socket)) {
    throw ForwardRefused(
      'The browser’s answer could not be forwarded to ${machine.name}: the folder of $socket is not yours alone.',
    );
  }
  // A forward a run of this interface left behind when it ended without asking holds the socket, or the port where it
  // was raised before the window held it: it is ended first, and given a moment to let go.
  final ended = forwardRecords?.endLeftovers((line) => forwardsPort(line, port)) ?? false;
  final waited = Stopwatch()..start();
  while (FileSystemEntity.typeSync(socket, followLinks: false) != FileSystemEntityType.notFound &&
      !await removeLeftover(socket) &&
      ended &&
      waited.elapsed < const Duration(seconds: 2)) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  if (FileSystemEntity.typeSync(socket, followLinks: false) != FileSystemEntityType.notFound) {
    throw ForwardRefused(
      'The browser’s answer could not be forwarded to ${machine.name}: something is at $socket, and it was left alone.',
    );
  }
  final relay = PersonOnlyRelay(
    {port: socket},
    loopbacks: [InternetAddress.loopbackIPv4, if (HostCardSsh.ipv6Loopback) InternetAddress.loopbackIPv6],
  );
  // One ended a moment ago may still hold the port.
  while (true) {
    try {
      await relay.hold();
      break;
    } on RelayRefused {
      if (!ended || waited.elapsed >= const Duration(seconds: 2)) throw _inUse(machine, port);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
  HeldSocket? made;
  // Only to the very socket ssh was seen to make, whatever is put at its name later.
  relay.routeTo = (to) => to == socket ? made?.through : null;
  try {
    if (master != null) {
      final asked = await _askedOfTheMaster(machine, master, port, socket);
      made = asked;
      return _Relayed(relay, socket, asked, () => _toTheMaster(machine, 'cancel', port, socket));
    }
    final command = loginForwardCommand(machine, port, socket: socket);
    final ssh = await startLoginForward(command);
    final records = forwardRecords?..record(ssh.pid, command);
    final said = ssh.stderr.transform(const SystemEncoding().decoder).join();
    // Proven by the kernel, never by ssh staying up: its own process listens on the very socket the relay goes to.
    for (var tries = 0; tries < 50; tries++) {
      final exited = await ssh.exitCode.timeout(const Duration(milliseconds: 100), onTimeout: () => -1);
      if (exited != -1) {
        records?.forget(ssh.pid);
        final words = (await said).trim();
        throw ForwardRefused(
          'The browser’s answer could not be forwarded to ${machine.name}: '
          '${words.isEmpty ? 'ssh ended with $exited' : words}',
        );
      }
      if (FileSystemEntity.typeSync(socket, followLinks: false) == FileSystemEntityType.unixDomainSock) {
        made = madeBy(ssh.pid, socket);
      }
      if (made != null) {
        final held = _Relayed(relay, socket, made, () async {
          ssh.kill();
          await ssh.exitCode.timeout(const Duration(seconds: 2), onTimeout: () => -1);
        });
        // An ssh that ends by itself lets go of the port too, so whoever looks finds the forward gone.
        unawaited(
          ssh.exitCode.then((_) {
            records?.forget(ssh.pid);
            unawaited(held.close());
          }),
        );
        return held;
      }
    }
    ssh.kill();
    await ssh.exitCode.timeout(const Duration(seconds: 2), onTimeout: () => -1);
    records?.forget(ssh.pid);
    throw ForwardRefused('Nothing on ${machine.name} answered on port $port for the browser’s answer.');
  } on Object {
    await relay.close();
    rethrow;
  }
}

/// Asks the master of [machine]'s card, process [master], to forward [socket] here to [port] on the machine, and proves
/// that the master made the socket: a client of it only passes the request on and ends.
Future<HeldSocket> _askedOfTheMaster(Machine machine, int master, int port, String socket) async {
  final asked = await startLoginForward(cardForwardCommand(machine, 'forward', port, socket));
  unawaited(asked.stdout.drain<void>());
  final said = asked.stderr.transform(const SystemEncoding().decoder).join();
  final exited = await asked.exitCode.timeout(
    const Duration(seconds: 10),
    onTimeout: () {
      asked.kill();
      return -1;
    },
  );
  if (exited != 0) {
    final words = (await said.timeout(const Duration(seconds: 1), onTimeout: () => '')).trim();
    throw ForwardRefused(
      'The browser’s answer could not be forwarded to ${machine.name}: '
      '${words.isEmpty ? 'ssh ended with $exited' : words}',
    );
  }
  for (var tries = 0; tries < 50; tries++) {
    if (FileSystemEntity.typeSync(socket, followLinks: false) == FileSystemEntityType.unixDomainSock) {
      if (madeBy(master, socket) case final made?) return made;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  await _toTheMaster(machine, 'cancel', port, socket);
  throw ForwardRefused('Nothing on ${machine.name} answered on port $port for the browser’s answer.');
}

/// Tells the master of [machine]'s card to [operation] (`cancel`) the forward of [socket] to [port], and waits for it.
Future<void> _toTheMaster(Machine machine, String operation, int port, String socket) async {
  try {
    final told = await startLoginForward(cardForwardCommand(machine, operation, port, socket));
    unawaited(told.stdout.drain<void>());
    unawaited(told.stderr.drain<void>());
    await told.exitCode.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        told.kill();
        return -1;
      },
    );
  } on ProcessException {
    // Nothing to tell it with: the master's own end takes the forward down.
  }
}

/// A card's request to its master: [operation] (`forward` or `cancel`) the forward of [socket] here to [port] on the
/// machine. The card reaches its machine only through the master, so the master, not this ssh, makes the socket.
List<String> cardForwardCommand(Machine machine, String operation, int port, String socket) => <String>[
  openSsh('ssh'),
  ...machine.loginSshOptions,
  '-o',
  'StreamLocalBindUnlink=no',
  '-O',
  operation,
  '-L',
  '$socket:localhost:$port',
  machine.host,
];

/// Where a login forward's ssh listens for [port] here, beside [machine]'s own socket.
String loginForwardSocket(Machine machine, int port) =>
    '${machine.socketPath.substring(0, machine.socketPath.lastIndexOf('/'))}/l-$port';

ForwardRefused _inUse(Machine machine, int port) => ForwardRefused(
  'Port $port is already in use on this computer, so the browser’s answer '
  'could not reach ${machine.name}. Close what uses it and try again.',
);

/// Where the kernel cannot name who opened a connection: ssh binds the port itself, as before.
Future<HeldForward> _bySshAlone(Machine machine, int port) async {
  if (forwardRecords?.endLeftovers((line) => forwardsPort(line, port)) ?? false) {
    final waited = Stopwatch()..start();
    while (waited.elapsed < const Duration(seconds: 2) && !await _free(port)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
  // Asked before, because ssh with ExitOnForwardFailure says only that it failed.
  if (!await _free(port)) throw _inUse(machine, port);
  final command = loginForwardCommand(machine, port);
  final ssh = await startLoginForward(command);
  final records = forwardRecords?..record(ssh.pid, command);
  unawaited(ssh.exitCode.then((_) => records?.forget(ssh.pid)));

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

Future<bool> _free(int port) async {
  try {
    final taken = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    await taken.close();
    return true;
  } on SocketException {
    return false;
  }
}

class _Ssh implements HeldForward {
  _Ssh(this._process);

  final Process _process;

  // The record goes once the process is seen gone, by the listener on its exit: one that ignores the end stays found.
  @override
  Future<void> close() async {
    _process.kill();
    await _process.exitCode.timeout(const Duration(seconds: 2), onTimeout: () => -1);
  }
}

/// A login forward the window relays: its port, held here, and the forward behind it, taken down by [_end].
class _Relayed implements HeldForward {
  _Relayed(this._relay, this._socket, this._made, this._end);

  final PersonOnlyRelay _relay;
  final String _socket;
  final HeldSocket _made;
  final Future<void> Function() _end;
  bool _closed = false;

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _relay.close();
    await _end();
    // Only the very socket its ssh was seen to make, and only while it is still that one.
    removeSocketIfStill(_socket, _made);
    _made.release();
  }
}

class _Nothing implements HeldForward {
  const _Nothing();

  @override
  Future<void> close() async {}
}

/// The reply forward, sharing the login terminal's destination and host-key policy.
/// [socket], where given, is where ssh listens here instead of on [port]: the window holds the port itself.
List<String> loginForwardCommand(Machine machine, int port, {String? socket}) => <String>[
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
  if (socket != null) ...<String>[
    // Whatever the person's config says, ssh never removes what is at the socket path before it binds there.
    '-o',
    'StreamLocalBindUnlink=no',
  ],
  '-L',
  '${socket ?? port}:localhost:$port',
  machine.host,
];
