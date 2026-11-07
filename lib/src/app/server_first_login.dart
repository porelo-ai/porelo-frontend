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
