import 'dart:io';

import 'package:porelo_host/porelo_host.dart';

import 'forge.dart';
import 'run_here.dart';

/// The entry of the test secrets file this instance reads its forge token from, named by `--forge-token-entry`; null
/// for the system store's own name of the forge.
String? forgeTokenEntry;

/// Reads `--forge-token-entry NAME` or `--forge-token-entry=NAME`, refusing a missing or unusable name.
String? forgeTokenEntryFromArguments(List<String> arguments) {
  String? entry;
  for (var index = 0; index < arguments.length; index++) {
    final argument = arguments[index];
    if (argument == '--forge-token-entry') {
      if (++index == arguments.length || arguments[index].startsWith('--')) {
        throw const FormatException('Expected an entry name after --forge-token-entry.');
      }
      entry = arguments[index];
    } else if (argument.startsWith('--forge-token-entry=')) {
      entry = argument.substring('--forge-token-entry='.length);
    }
  }
  if (entry != null && !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:/@-]*$').hasMatch(entry)) {
    throw FormatException('"$entry" is no entry name: letters, digits and ".", "_", ":", "/", "@", "-".');
  }
  return entry;
}

/// A KeePassXC file opened by its key file alone, with no master password: the test secrets file that
/// `prepare-github-test-token.sh` writes and `drop-github-test-token.sh` deletes.
class KeyFileSecrets {
  /// Names the file and its key file, both absolute paths on this desktop.
  KeyFileSecrets(this.file, this.keyFile, {this.cli = SecretsFile.keepassxcCli}) {
    SecretsFile.checkPath(file);
    SecretsFile.checkPath(keyFile);
    SecretsFile.checkPath(cli);
  }

  /// The test secrets file of the account running this interface, `/run/user/<uid>/porelo-test/`, or null where this
  /// desktop has no such folder. Named by the account's id, not by `XDG_RUNTIME_DIR`, which a second instance of the
  /// same account points elsewhere.
  static KeyFileSecrets? test({String status = '/proc/self/status'}) {
    final String text;
    try {
      text = File(status).readAsStringSync();
    } on FileSystemException {
      return null;
    }
    final uid = RegExp(r'^Uid:\s+(\d+)', multiLine: true).firstMatch(text)?.group(1);
    if (uid == null) return null;
    final folder = '/run/user/$uid/porelo-test';
    return KeyFileSecrets('$folder/secrets.kdbx', '$folder/secrets.key');
  }

  /// The secrets file.
  final String file;

  /// The key file that opens it.
  final String keyFile;

  /// The `keepassxc-cli` that opens it.
  final String cli;

  /// Whether both files are there now; `prepare-github-test-token.sh` writes them and the drop deletes them.
  bool get present => File(file).existsSync() && File(keyFile).existsSync();

  /// The options that open the file with its key file and no password, after `keepassxc-cli`'s command.
  List<String> get opening => ['--no-password', '--key-file', keyFile];
}

/// Forge tokens read from the test secrets file while it is there, otherwise from this computer's system store.
///
/// The test secrets file is written only by `prepare-github-test-token.sh`: nothing is written to it from here, and a
/// token typed for a forge then goes to the system store as before.
class KeyFileForgeTokens implements ForgeTokens {
  /// Reads [secrets] while it is present, falling back to [otherwise]; [run] runs `keepassxc-cli`. [entry] names the
  /// entry read for every forge, where this instance was started with one.
  KeyFileForgeTokens(this.secrets, this.otherwise, {this.entry, RunHere? run}) : _run = run ?? runHere;

  /// The one entry this instance reads, or null for each forge's own name.
  final String? entry;

  /// The test secrets file.
  final KeyFileSecrets secrets;

  /// Where tokens are kept when the test secrets file is not there.
  final ForgeTokens otherwise;

  final RunHere _run;

  // keepassxc-cli's own words in English, so a missing file reads the same on every desktop; none is matched here.
  static const _english = {'LC_ALL': 'C.UTF-8', 'LANGUAGE': ''};

  @override
  Future<String?> read(String forge) async {
    if (!secrets.present) return otherwise.read(forge);
    final entry = this.entry ?? providerKeyName(forgeAddress(forge));
    final listed = await _cli(['ls', '-q', '-R', '-f', ...secrets.opening, secrets.file]);
    if (listed.code != 0) {
      throw ForgeRefused('${secrets.file} did not open with its key file ${secrets.keyFile}.');
    }
    if (!listed.out.split('\n').contains(entry)) return null;
    final shown = await _cli(['show', '-s', '-a', 'password', ...secrets.opening, secrets.file, entry]);
    if (shown.code != 0) throw ForgeRefused('$entry in ${secrets.file} could not be read.');
    final token = shown.out.endsWith('\n') ? shown.out.substring(0, shown.out.length - 1) : shown.out;
    return token.isEmpty ? null : token;
  }

  @override
  Future<void> write(String forge, String token) async => secrets.present
      ? throw ForgeRefused(
          '${secrets.file} is the test secrets file, written only by prepare-github-test-token.sh; nothing was kept.',
        )
      : otherwise.write(forge, token);

  @override
  Future<void> delete(String forge) async => secrets.present
      ? throw ForgeRefused(
          '${secrets.file} is the test secrets file; drop-github-test-token.sh removes it. Nothing was deleted.',
        )
      : otherwise.delete(forge);

  Future<Ran> _cli(List<String> arguments) async {
    try {
      return await _run(secrets.cli, arguments, environment: _english);
    } on ProcessException {
      throw ForgeRefused('KeePassXC\'s command line is not installed here (${secrets.cli}).');
    }
  }
}
