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

/// The variable Core's registry check takes the organization's installation token from, declared once by
/// `prepare-github-test-token.sh` with `porelo credentials declare … --env`.
const registryTokenVariable = 'PORELO_GITHUB_APP_TOKEN';

/// The environment for Core's `porelo registry …` of an instance started with [entry]: the token of a GitHub App's
/// installation entry (`github-app-<id>-installation`), read from the test secrets file at each call and kept nowhere.
/// An instance started with a person's own entry, or none, takes the organization's installation entry the file holds:
/// Core's owner check of the registry asks the organization, which a developer's own token cannot answer. Nothing
/// while the test secrets file is not there, when Core takes its vault as before.
Future<Map<String, String>> Function() registryEnvironmentFor(
  String? entry, {
  KeyFileSecrets? Function()? secrets,
  RunHere? run,
}) => () async {
  final test = (secrets ?? KeyFileSecrets.test)();
  if (test == null || !test.present) return const {};
  final tokens = KeyFileForgeTokens(test, MemoryForgeTokens(), entry: entry, run: run);
  final app = entry != null && entry.startsWith('github-app-') ? entry : await tokens.installationEntry();
  if (app == null) return const {};
  final token = await KeyFileForgeTokens(test, MemoryForgeTokens(), entry: app, run: run).read('github.com');
  return token == null ? const {} : {registryTokenVariable: token};
};

/// The secrets file the central push and pull read their token from: the test secrets file while it is there, opened by
/// its key file with no master password, at the instance's own installation entry ([entry], from
/// `--forge-token-entry`) or the one the file holds; otherwise the person's own [chosen] file at `forge-central-token`,
/// its master password typed in the terminal. Null where neither is there.
Future<SecretsFile?> centralTransferSecrets(
  String? chosen, {
  String? entry,
  KeyFileSecrets? Function()? secrets,
  RunHere? run,
}) async {
  final test = (secrets ?? KeyFileSecrets.test)();
  if (test == null || !test.present) return chosen == null ? null : SecretsFile(chosen);
  final app = entry != null && entry.startsWith('github-app-')
      ? entry
      : await KeyFileForgeTokens(test, MemoryForgeTokens(), run: run).installationEntry();
  if (app == null) {
    throw ForgeRefused(
      '${test.file} holds no github-app-<id>-installation entry to read the central token from; nothing was sent.',
    );
  }
  return SecretsFile(test.file, cli: test.cli, keyFile: test.keyFile, entry: app);
}

/// Whether [centralTransferSecrets] has a file to read: the person's own [chosen] one or the test secrets file.
bool hasCentralTransferSecrets(String? chosen, {KeyFileSecrets? Function()? secrets}) =>
    chosen != null || ((secrets ?? KeyFileSecrets.test)()?.present ?? false);

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

  /// The organization's GitHub App installation entry the test secrets file holds, `github-app-<id>-installation`, or
  /// null where it holds none.
  Future<String?> installationEntry() async {
    if (!secrets.present) return null;
    final listed = await _cli(['ls', '-q', '-R', '-f', ...secrets.opening, secrets.file]);
    if (listed.code != 0) {
      throw ForgeRefused('${secrets.file} did not open with its key file ${secrets.keyFile}.');
    }
    return listed.out
        .split('\n')
        .where((name) => RegExp(r'^github-app-[0-9]+-installation$').hasMatch(name))
        .firstOrNull;
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
