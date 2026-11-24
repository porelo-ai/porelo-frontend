import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:porelo_host/porelo_host.dart'
    show HostFileWriter, checkHostName, missingPoreloHost, pinnedHostSshOptions, poreloHostCommand;

import '../client/host_identity.dart';
import 'host_session.dart' show StartHostCommand;
import 'machines.dart';
import 'owned_process.dart';
import 'ssh_console.dart' show ownConnection;

/// Why a host's identity could not be read from it; its words never hold what the host printed on its output.
final class HostIdentityExportRefused implements Exception {
  /// Takes the words for a person.
  const HostIdentityExportRefused(this.words);

  /// Why, for a person.
  final String words;

  @override
  String toString() => words;
}

/// The most a host's identity may be, as the vault keeps it.
const _most = 256 * 1024;

/// Reads the identity of the host [hostName] from [machine] itself, as root through its pinned connection, in memory.
///
/// It ends within [limit] and at [_most] bytes, whatever the host does; the identity is never in an argument or a file.
Future<HostIdentity> exportHostIdentity(
  Machine machine, {
  required String hostName,
  StartHostCommand? start,
  Duration limit = const Duration(seconds: 30),
  Future<void>? cancelled,
}) async {
  // ssh would read such a host as an option, and an option can run a command here.
  if (machine.host.isEmpty || machine.host.startsWith('-')) {
    throw HostIdentityExportRefused('$hostName has no address this computer can reach it at.');
  }
  final List<String> options;
  try {
    final login = machine.loginSshOptions;
    // A card's login goes through its shared master, which names no login: root's gets a connection of its own.
    options = login.contains('ProxyCommand=false') ? ownConnection(login) : login;
  } on Exception catch (error) {
    throw HostIdentityExportRefused("$hostName's SSH configuration could not be found: $error");
  } on StateError catch (error) {
    throw HostIdentityExportRefused(error.message);
  }
  return _export(hostName, 'root@${machine.host}', options, start: start, limit: limit, cancelled: cancelled);
}

/// Reads the identity of [hostName] through its verified card's published SSH configuration [config], as root on a
/// connection of its own: a host this window never connected to as a machine.
Future<HostIdentity> exportHostIdentityByCard(
  String config, {
  required String hostName,
  StartHostCommand? start,
  Duration limit = const Duration(seconds: 30),
  Future<void>? cancelled,
}) {
  checkHostName(hostName);
  return _export(
    hostName,
    'root@$hostName',
    ownConnection(['-F', config, '-o', 'ControlMaster=no', '-o', 'ProxyCommand=false']),
    start: start,
    limit: limit,
    cancelled: cancelled,
  );
}

/// Reads the identity of [hostName] at [address] as porelo-host itself reaches it: [hostKey] alone trusted, in a
/// known_hosts of its own that is gone with the read, the agent's keys alone, and no configuration of this computer.
Future<HostIdentity> exportHostIdentityPinned({
  required String hostName,
  required String address,
  required String hostKey,
  int port = 22,
  StartHostCommand? start,
  Duration limit = const Duration(seconds: 30),
  Future<void>? cancelled,
}) async {
  if (address.isEmpty || address.startsWith('-') || hostKey.isEmpty || hostKey.contains('\n')) {
    throw HostIdentityExportRefused('$hostName has no address and host key this computer can reach it by.');
  }
  final writer = HostFileWriter();
  final pinned = await writer.createPrivateTemporary(Directory.systemTemp, prefix: 'porelo-identity-');
  try {
    final knownHosts = File('${pinned.path}${Platform.pathSeparator}known_hosts');
    await knownHosts.writeAsString('${port == 22 ? address : '[$address]:$port'} $hostKey\n');
    // Named by its host name, reached at its address: ssh reads no address as an option or a login.
    return await _export(
      hostName,
      hostName,
      [
        ...pinnedHostSshOptions(knownHosts.path, ''),
        '-F',
        '/dev/null',
        '-o',
        'PreferredAuthentications=publickey',
        '-o',
        'HostName=$address',
        '-o',
        'User=root',
        '-o',
        'Port=$port',
      ],
      start: start,
      limit: limit,
      cancelled: cancelled,
    );
  } finally {
    await pinned.delete(recursive: true).catchError((Object _) => pinned);
  }
}

Future<HostIdentity> _export(
  String hostName,
  String destination,
  List<String> options, {
  required StartHostCommand? start,
  required Duration limit,
  required Future<void>? cancelled,
}) async {
  if (destination.isEmpty || destination.startsWith('-') || destination.endsWith('@')) {
    throw HostIdentityExportRefused('$hostName has no address this computer can reach it at.');
  }
  // A host whose SSH configuration this computer does not hold is not reached: no ssh starts for it.
  final config = options.indexOf('-F');
  if (start == null && config >= 0 && config + 1 < options.length && options[config + 1] != '/dev/null') {
    if (!await File(options[config + 1]).exists()) {
      throw HostIdentityExportRefused("This computer holds no SSH configuration for $hostName: connect to it first.");
    }
  }
  final Process process;
  try {
    process = await (start ?? Process.start)(openSsh('ssh'), [
      ...options,
      '-T',
      '-o',
      'BatchMode=yes',
      '-o',
      'ForwardAgent=no',
      destination,
      poreloHostCommand('identity export'),
    ]);
  } on ProcessException {
    throw const HostIdentityExportRefused('SSH could not run on this computer.');
  }
  unawaited(process.stdin.close().catchError((Object _) {}));
  final out = <int>[];
  final err = StringBuffer();
  final ended = Completer<String?>();
  Timer? timer;
  void stop(String why) {
    if (ended.isCompleted) return;
    // At once, not after the read is taken up: a window that closes leaves no timer behind.
    timer?.cancel();
    ended.complete(why);
    unawaited(stopOwnedProcess(process).catchError((Object _) {}));
  }

  final outEnded = Completer<void>();
  final errEnded = Completer<void>();
  final reading = process.stdout.listen(
    (chunk) {
      out.addAll(chunk);
      if (out.length > _most) stop('$hostName printed more than an identity can be.');
    },
    onError: (Object _) {},
    onDone: outEnded.complete,
  );
  // A byte that is no UTF-8 is shown as one, never an error that ends the read.
  final saying = process.stderr
      .transform(const Utf8Decoder(allowMalformed: true))
      .listen(
        (words) {
          // Only its last words are said: what an error says fits in far less.
          if (err.length < 4096) err.write(words);
        },
        onError: (Object _) {},
        onDone: errEnded.complete,
      );
  timer = Timer(limit, () => stop('$hostName did not answer within ${limit.inSeconds} seconds.'));
  unawaited(cancelled?.then((_) => stop('The window closed before $hostName answered.')));
  int? code;
  unawaited(
    process.exitCode.then((exit) async {
      code = exit;
      // Its last words may reach this computer after it ended: they are what says why it refused.
      await Future.wait([outEnded.future, errEnded.future])
          .timeout(const Duration(seconds: 5), onTimeout: () => const []);
      if (!ended.isCompleted) {
        timer?.cancel();
        ended.complete(null);
      }
    }),
  );
  final refused = await ended.future;
  unawaited(reading.cancel());
  unawaited(saying.cancel());
  if (refused != null) throw HostIdentityExportRefused(refused);
  if (code != 0) {
    if (missingPoreloHost(hostName, code!) case final missing?) throw HostIdentityExportRefused(missing);
    final said = _plain(err.toString().trim().split('\n').last.trim());
    throw HostIdentityExportRefused(
      '$hostName did not give its identity: ${said.isEmpty ? 'it ended with $code, and did not say why' : said}.',
    );
  }
  final Object? value;
  try {
    value = jsonDecode(utf8.decode(out));
  } on FormatException {
    throw HostIdentityExportRefused('$hostName answered with something that is not an identity.');
  }
  final HostIdentity identity;
  try {
    identity = HostIdentity.read(value);
  } on FormatException {
    throw HostIdentityExportRefused('$hostName answered with something that is not an identity.');
  }
  if (identity.host != hostName) {
    throw HostIdentityExportRefused('$hostName answered, but not the identity of $hostName.');
  }
  return identity;
}

/// [words] without control characters, which a terminal or a log would read as commands.
String _plain(String words) => words.replaceAll(RegExp(r'[\x00-\x1f\x7f-\x9f]'), ' ');
