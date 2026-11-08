import 'package:flutter/foundation.dart';
import 'package:porelo_host/porelo_host.dart' show inTheLoginShell, quoteForAShell;

import 'package:porelo_frontend/client.dart';

import 'fleet_backend.dart';
import 'desk.dart';
import 'machines.dart';
import 'wsl.dart';

export 'package:porelo_host/porelo_host.dart' show inTheLoginShell, quoteForAShell;

/// How one machine connects out: the credentials it is configured with, described without a
/// secret, and the declaring and forgetting of them.
///
/// **The description travels, the value never does.** Declaring writes what a credential is for and
/// where its value lives; the value is stored on the machine by the command the machine names.
class Connections extends ChangeNotifier {
  int _asked = 0;

  /// Drops another machine's rows before a connection or a read can wait.
  void prepareFor(String machine) {
    if (this.machine == machine) return;
    _asked++;
    this.machine = machine;
    all = const [];
    read = false;
    vaultOpen = false;
    declared = null;
    forgotten = null;
    problem = null;
    busy = false;
    notifyListeners();
  }

  /// Which machine, by name, once looked at.
  String machine = '';

  /// What it is configured with. Read with the vault shut too.
  List<Connection> all = const <Connection>[];

  /// Whether [all] is an answer of this machine, and not merely nothing asked yet.
  bool read = false;

  /// Whether the vault could be read, which is what `present` means anything beside.
  bool vaultOpen = false;

  /// What the last declaring wrote, and how its value is stored.
  CredentialDeclared? declared;

  /// What the last forgetting did.
  CredentialForgotten? forgotten;

  /// Whether the machine is being asked right now.
  bool busy = false;

  /// Why it could not be asked, in words.
  String? problem;

  /// Reads what [backend]'s machine connects out with.
  Future<void> lookAt(FleetBackend backend, String machine) async {
    prepareFor(machine);
    final asked = ++_asked;
    declared = null;
    forgotten = null;
    await _asking(() => _read(backend, asked), asked: asked);
  }

  /// Declares a connection; its value, if it has one to store, is stored next.
  Future<void> declare(
    FleetBackend backend, {
    required String kind,
    required String match,
    String? id,
    String? user,
    String? purpose,
    String? source,
    String? fromFile,
  }) async {
    final asked = _asked;
    forgotten = null;
    await _asking(() async {
      final answer = await backend.credentialDeclare(
        kind: kind,
        match: match,
        id: id,
        user: user,
        purpose: purpose,
        source: source,
        fromFile: fromFile,
      );
      if (asked != _asked) return;
      declared = answer;
      await _read(backend, asked);
    }, asked: asked);
  }

  /// Forgets the record for [match]. The secret stays where it is, and the answer says where.
  Future<void> forget(FleetBackend backend, String match) async {
    final asked = _asked;
    declared = null;
    await _asking(() async {
      final answer = await backend.credentialForget(match);
      if (asked != _asked) return;
      forgotten = answer;
      await _read(backend, asked);
    }, asked: asked);
  }

  /// Puts what the last act answered away.
  void letItBe() {
    declared = null;
    forgotten = null;
    notifyListeners();
  }

  /// What forgetting did, in one line — never implying the secret is gone when something holds it.
  String get forgottenWords {
    final said = forgotten;
    if (said == null) return '';
    if (!said.forgotten) return 'Nothing was recorded for that address.';
    return said.leftBehind.isEmpty
        ? 'Forgotten. Nothing else held its value.'
        : 'Forgotten. Its value is still there: ${said.leftBehind}. Remove that at the machine if '
              'it should go too.';
  }

  Future<void> _read(FleetBackend backend, int asked) async {
    final store = await backend.credentials();
    if (asked != _asked) return;
    all = store.connections;
    read = true;
    vaultOpen = store.readable;
  }

  Future<void> _asking(Future<void> Function() ask, {required int asked}) async {
    busy = true;
    problem = null;
    notifyListeners();
    try {
      await ask();
    } on VarlinkException catch (refusal) {
      if (asked != _asked) return;
      final said = refusal.parameters['message'];
      problem = said is String && said.isNotEmpty ? said : 'Refused: ${refusal.simpleName}.';
    } on VarlinkDisconnected catch (ex) {
      if (asked != _asked) return;
      problem = 'Lost contact with the machine: ${ex.message}';
    } on FeatureNotSupported catch (ex) {
      if (asked != _asked) return;
      problem = '$ex';
    } on StateError {
      if (asked != _asked) return;
      // Asked before the machine's socket was open: said, never an unhandled error.
      problem = 'The machine has not answered yet. Ask again once it does.';
    } finally {
      if (asked == _asked) {
        busy = false;
        notifyListeners();
      }
    }
  }
}

/// [command], as the machine named it, run on [machine]: over ssh for a machine this interface
/// reaches that way, here for this computer's own daemon, and nowhere for a socket somebody else
/// forwards — a command run here would reach a different machine's vault. [terminal] asks ssh for
/// one, which a command that prompts needs and one fed on standard input must not have.
List<String>? onTheMachine(Machine machine, List<String> command, {required bool terminal}) {
  if (command.isEmpty || machine.host.startsWith('-')) return null;
  if (machine.relay?.kind == 'wsl') return Wsl.runIn(machine.distribution, command);
  if (machine.needsATunnel) {
    // ssh joins what follows the host into one line for the far shell, so each word is quoted.
    return <String>[
      openSsh('ssh'),
      ...machine.loginSshOptions,
      if (terminal) '-t',
      if (!terminal && desk.isWindows && machine.kind != 'host') ...<String>['-o', 'BatchMode=yes'],
      machine.host,
      inTheLoginShell(command.map(quoteForAShell).join(' ')),
    ];
  }
  if (machine.host.isEmpty && machine.socketPath == Backend.local().socketPath) return command;
  return null;
}

/// Why [value] is not a private ssh key, or null when it is one. Only the private key is sent: the
/// machine works out the public half from it, and a public one stored in its place fails at the
/// first fetch as a refused login, far from where the wrong file was chosen.
String? notAPrivateKey(String value) {
  final text = value.trim();
  if (text.isEmpty) return 'There is nothing in it to send.';
  if (RegExp(r'^-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----').hasMatch(text) &&
      RegExp(r'-----END [A-Z0-9 ]*PRIVATE KEY-----$').hasMatch(text)) {
    return null;
  }
  if (RegExp(r'^(ssh-|ecdsa-|sk-)\S+ ').hasMatch(text) || text.contains('PUBLIC KEY-----')) {
    return 'That is the public half of a key. Send the private one — usually the same name '
        'without .pub; the machine works out the public half from it.';
  }
  return 'That is not a private key: a private key begins with -----BEGIN … PRIVATE KEY----- '
      'and ends with -----END … PRIVATE KEY-----.';
}

/// [line], exactly as the machine wrote it, run there by its own shell: over ssh, whose far end
/// hands one line to the shell, or here with `sh -c`. **Never split here** — a line this end did not
/// write is not one it may take apart. Null where nothing here reaches that machine.
List<String>? onTheMachineAsWritten(Machine machine, String line) {
  if (line.trim().isEmpty || machine.host.startsWith('-')) return null;
  if (machine.relay?.kind == 'wsl') return Wsl.runIn(machine.distribution, <String>['sh', '-c', line]);
  if (machine.needsATunnel) {
    return <String>[openSsh('ssh'), ...machine.loginSshOptions, '-t', machine.host, inTheLoginShell(line)];
  }
  if (machine.host.isEmpty && machine.socketPath == Backend.local().socketPath) {
    return <String>['sh', '-c', line];
  }
  return null;
}
