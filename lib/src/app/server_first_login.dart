import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:porelo_host/porelo_host.dart'
    show HostFileWriter, Remote, RemoteResult, isProvidersRootRefusal, pinnedHostSshPolicy;

import 'machines.dart' show openSsh;

/// The one host key a person compared, pinned in a private folder of its own, so that the first login and the root
/// try trust it alone and the person's own `known_hosts` is neither read nor written.
class ComparedKeyPin {
  ComparedKeyPin._(this._folder, this.file);

  /// A pin at [file] in [folder], made elsewhere: for a widget test, whose clock never ends real file work.
  @visibleForTesting
  ComparedKeyPin.at(Directory folder, this.file) : _folder = folder;

  /// Pins [hostKey] for [address] in a new private folder under [parent], the system's temporary one by default.
  static Future<ComparedKeyPin> make(String address, String hostKey, {Directory? parent}) async {
    final writer = HostFileWriter();
    final folder = await writer.createPrivateTemporary(parent ?? Directory.systemTemp, prefix: 'porelo-first-login-');
    final file = File('${folder.path}${Platform.pathSeparator}known_hosts');
    await file.writeAsString('$address ${hostKey.trim()}\n', flush: true);
    return ComparedKeyPin._(folder, file);
  }

  final Directory _folder;

  /// The `known_hosts` holding the compared key alone.
  final File file;

  /// Removes the pin and its folder.
  Future<void> dispose() async {
    if (await _folder.exists()) await _folder.delete(recursive: true);
  }
}

/// The terminal's command for the provider's first login as [user] at [address], trusting only [pin]'s key.
///
/// No `BatchMode`: the login may ask for a key's passphrase, and the line it runs for `sudo`'s password.
List<String> firstLoginCommand({required String pin, required String user, required String address}) => [
  openSsh('ssh'),
  for (final MapEntry(:key, :value) in pinnedHostSshPolicy(pin).entries)
    if (key != 'BatchMode' && key != 'IdentitiesOnly') ...['-o', '$key=$value'],
  '-o',
  'ControlMaster=no',
  '-o',
  'ControlPath=none',
  '-t',
  '--',
  '$user@$address',
];

/// What a root login with the card key came to.
enum RootLoginState {
  /// Root logged in with the card key.
  open,

  /// Root answers with the provider's "log in as" line: the bootstrap line has not run.
  providersLine,

  /// Root refused the card key.
  refused,

  /// Nothing that says either: the machine not reached, or ssh failing.
  noAnswer,
}

/// A root login's state and the words that say it.
typedef RootLogin = ({RootLoginState state, String words});

/// Reads what `ssh root@… true` ended with: [exit], what came on standard output, and on standard error.
RootLogin readRootLogin(int exit, String out, String err) {
  final last = _lastLine(err).isNotEmpty ? _lastLine(err) : _lastLine(out);
  if (isProvidersRootRefusal(out) || isProvidersRootRefusal(err) || exit == 142) {
    return (
      state: RootLoginState.providersLine,
      words:
          'The bootstrap line has not run: root still answers with the provider\'s line'
          '${last.isEmpty ? '' : ' "$last"'}. Run it in the terminal on the server, then try again.',
    );
  }
  if (exit == 0) return (state: RootLoginState.open, words: 'Root logs in with your Machine Admin card key.');
  if (exit == 255 && err.contains('Permission denied')) {
    return (
      state: RootLoginState.refused,
      words:
          'Root refused your Machine Admin card key. Run the bootstrap line in the terminal on the server, then try '
          'again.',
    );
  }
  if (exit == 255 && (err.contains('Host key verification failed') || err.contains('IDENTIFICATION HAS CHANGED'))) {
    return (
      state: RootLoginState.noAnswer,
      words: 'The server answered with another SSH host key than the one you compared. Go back to its SSH host key.',
    );
  }
  return (
    state: RootLoginState.noAnswer,
    words: last.isEmpty
        ? 'The root login ended with exit $exit and said nothing.'
        : 'The root login said: $last (exit $exit)',
  );
}

/// Logs in as root through [remote] and runs `true`, saying what came of it.
Future<RootLogin> tryRootLogin(Remote remote, String address) async {
  final out = StringBuffer();
  final RemoteResult result;
  try {
    result = await remote.run(address, 'root', 'true', onLine: (line) => out.writeln(line));
  } on Exception catch (error) {
    return (state: RootLoginState.noAnswer, words: 'ssh could not be started on this computer: $error');
  }
  return readRootLogin(result.exitCode, '$out', result.stderr);
}

/// A machine's last word, one short line with nothing that could move a terminal.
String _lastLine(String words) {
  final lines = words.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty);
  if (lines.isEmpty) return '';
  final last = lines.last.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ');
  return last.length <= 200 ? last : '${last.substring(0, 200)}…';
}

/// The bootstrap [line] as *Run it for me* runs it: every `sudo` told never to ask, so a password wanted ends it.
String unaskedBootstrapLine(String line) =>
    line.replaceAllMapped(RegExp(r'(^|&& |\| )sudo '), (match) => '${match[1]}sudo -n ');

/// The first login as [user] at [address] running [command] unasked, trusting only [pin]'s key.
///
/// `BatchMode`: nothing may wait for a passphrase or a password nobody can type here. The person's own keys and agent
/// log in, as in the terminal; only the host key is the pin's.
List<String> firstLoginRunArguments({
  required String pin,
  required String user,
  required String address,
  required String command,
}) => [
  for (final MapEntry(:key, :value) in pinnedHostSshPolicy(pin).entries)
    if (key != 'IdentitiesOnly') ...['-o', '$key=$value'],
  '-o',
  'ControlMaster=no',
  '-o',
  'ControlPath=none',
  '-T',
  '--',
  '$user@$address',
  command,
];

/// What running the bootstrap line by the first login came to.
enum BootstrapRunState {
  /// The line ran to its end.
  ran,

  /// `sudo` wants a password: the terminal is the way.
  wantsPassword,

  /// The first login could not be made without asking, or the server was not reached.
  noLogin,

  /// The line ran and failed.
  failed,
}

/// A bootstrap run's state and the words that say it.
typedef BootstrapRun = ({BootstrapRunState state, String words});

/// Reads what the first login's run of the bootstrap line ended with.
BootstrapRun readBootstrapRun(int exit, String out, String err) {
  final last = _lastLine(err).isNotEmpty ? _lastLine(err) : _lastLine(out);
  if (exit == 0) return (state: BootstrapRunState.ran, words: 'The bootstrap line ran on the server.');
  if (err.contains('a password is required') || err.contains('a terminal is required')) {
    return (
      state: BootstrapRunState.wantsPassword,
      words: 'sudo on the server wants your password. Open a terminal on the server and paste the line there.',
    );
  }
  if (exit == 255) {
    return (
      state: BootstrapRunState.noLogin,
      words:
          'The first login could not be made without asking${last.isEmpty ? '' : ': $last'}. Open a terminal on the '
          'server and paste the line there.',
    );
  }
  return (
    state: BootstrapRunState.failed,
    words: last.isEmpty
        ? 'The bootstrap line ended with exit $exit and said nothing.'
        : 'The bootstrap line said: $last (exit $exit)',
  );
}
