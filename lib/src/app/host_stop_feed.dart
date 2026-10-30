import 'package:porelo_host/porelo_host.dart';

/// The command the stop's terminal runs on this desktop when the host takes its secrets from the person's file.
///
/// The drive's login, where the host still names it, runs first in a terminal of its own on the host, as
/// [driveHost] (the account, as today's stop). Then the file's lines for [needs], and for [keys], the vault entries
/// `machine.yml` names, go on a pipe into `porelo-host-stop --stdin` as [host], with sudo for the root and legacy
/// acts: the master password is typed once, here, and no secret reaches an argument, the far end's terminal or
/// this program. An own-account stop takes its needs from the project's own `setup/<project>/machine.yml`;
/// fixed bundle names do not change the secret-line protocol.
List<String> hostStopFeedCommand({
  required HostAct act,
  required String secretsFile,
  required String project,
  required List<String> needs,
  List<String> keys = const [],
  required String ssh,
  required List<String> sshOptions,
  required String host,
  String? driveHost,
  String email = '',
  String cli = SecretsFile.keepassxcCli,
  String? caOut,
  int networkNumber = 0,
  String? secretsHost,
}) {
  final allowed = switch (act) {
    HostAct.root => const {'wireguard', 'forge-certificate'},
    // identities gives no line: the host's stop reads the tokens admission left in the person's own folder.
    HostAct.ownAccount => const {'vault-new', 'vault', 'keys', 'forge-central-token', 'identities'},
    HostAct.legacyUp => const {
      'vault',
      'vault-new',
      'wireguard',
      'keys',
      'forge-central-token',
      'forge-certificate',
      'drive',
      'matrix-token',
    },
  };
  for (final need in needs) {
    if (!allowed.contains(need)) {
      throw FormatException('The ${act.name} stop does not accept $need.');
    }
  }
  final unknown = needs.where(
    (need) =>
        need != 'drive' && need != 'matrix-token' && need != 'identities' && !SecretsFile.stopNeeds.contains(need),
  );
  if (unknown.isNotEmpty) {
    throw FormatException('The host asked for ${unknown.join(', ')}, which the secrets file does not give.');
  }
  final fed = needs.where(SecretsFile.stopNeeds.contains).toList();
  // The host's registration token for this computer's homeserver comes from this computer's own Porelo, not the file.
  final matrix = needs.contains('matrix-token');
  final identities = needs.contains('identities');
  if (fed.isEmpty && !matrix && !identities) {
    throw const FormatException('The host asks for nothing the secrets file gives.');
  }
  // Where the lasting CA's certificate is written, public, once the forge's request is signed.
  if (caOut != null) SecretsFile.checkPath(caOut);
  // The program that receives every secret on its standard input is taken by its path, never by PATH.
  if (!ssh.startsWith('/')) throw const FormatException('ssh is run by its absolute path.');
  final login = RegExp(r'^[A-Za-z_][A-Za-z0-9_-]*@[A-Za-z0-9][A-Za-z0-9.:-]*$');
  for (final each in [host, if (needs.contains('drive')) driveHost ?? host]) {
    if (!login.hasMatch(each)) throw FormatException('The host stop did not name a valid user and address: $each.');
  }
  if (act == HostAct.ownAccount && host.startsWith('root@')) {
    throw const FormatException('The own-account stop needs the person\'s login, never root.');
  }
  if (act == HostAct.ownAccount) {
    final pinned = pinnedHostSshOptions('', '');
    for (var index = 0; index < pinned.length || index < sshOptions.length; index += 2) {
      final option = index < sshOptions.length ? sshOptions[index] : '';
      final value = index + 1 < sshOptions.length ? sshOptions[index + 1] : '';
      final expected = index < pinned.length ? pinned[index] : '';
      final expectedValue = index + 1 < pinned.length ? pinned[index + 1] : '';
      final matches =
          option == expected &&
          expected.isNotEmpty &&
          switch (expectedValue) {
            'UserKnownHostsFile=""' => RegExp(r'^UserKnownHostsFile="/[^"\r\n\x00]+"$').hasMatch(value),
            '' => value.startsWith('/') && !RegExp(r'[\r\n\x00]').hasMatch(value),
            _ => value == expectedValue,
          };
      if (!matches) {
        throw FormatException(
          'The own-account stop does not accept SSH option $option $value; expected $expected $expectedValue.',
        );
      }
    }
  }
  // The project reaches this computer's Porelo as a word of its own, never as an option.
  if (matrix && !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(project)) {
    throw FormatException('The project $project is not one this computer can let a host in for.');
  }
  final feed = [
    if (fed.isNotEmpty)
      SecretsFile(secretsFile, cli: cli).stopLines(
        host: secretsHost ?? project,
        project: act == HostAct.root ? '' : project,
        needs: fed,
        keys: fed.contains('keys') ? keys : const [],
        networkNumber: networkNumber,
      ),
    if (matrix)
      r"printf 'matrix-token %s\n' "
          '"\$matrixtoken"',
  ].join('\n');
  String sshLine(List<String> arguments) => [ssh, ...sshOptions, ...arguments].map(quoteForAShell).join(' ');
  // No login shell at the far end: its profile would run with the pipe on its standard input. `-n`: a sudo that
  // asks a password fails instead of reading one from the pipe.
  final stop =
      '${act == HostAct.ownAccount ? '' : '/usr/bin/sudo -n '}'
      '/usr/local/bin/porelo-host-stop --stdin ${[...fed, if (identities) 'identities', if (matrix) 'matrix-token'].join(' ')}';
  final script = [
    if (matrix) ...[
      // The folder exists before anything can leave it behind; any end of the terminal takes it away.
      r'admitted="$(/usr/bin/mktemp -d)" || exit 1',
      "trap '/usr/bin/stty echo 2>/dev/null || true; /usr/bin/rm -rf -- \"\$admitted\"' EXIT",
      "trap 'exit 1' HUP INT TERM",
    ] else
      "trap '/usr/bin/stty echo 2>/dev/null || true' EXIT",
    'set -o pipefail',
    // This computer lets the host into the project's conversation; the admission, its token among it, lies in a
    // folder of the person's own only until the token is read from it.
    if (matrix) ...[
      // The host goes by its own hostname in the room, as its Porelo passes it at its first setup; read there.
      'machine="\$(${sshLine(['-n', '-T', '--', host, '/usr/bin/hostname'])})" '
          '|| { echo "The host did not say its name; nothing was sent." >&2; exit 1; }',
      // In the C locale, so a range is ASCII alone: a letter or digit first, then those, dots, dashes, underscores.
      r'''LC_ALL=C; case "$machine" in [A-Za-z0-9]*) ;; *) machine=;; esac; case "$machine" in ''|*[!A-Za-z0-9._-]*) echo "The host's name is not one a machine goes by; nothing was sent." >&2; exit 1;; esac''',
      '/usr/bin/porelo talk admit ${quoteForAShell(project)} "\$machine" '
          '--into "\$admitted/admission.json" >/dev/null '
          '|| { echo "This computer\'s Porelo did not let the host into the project\'s conversation; nothing was sent." >&2; exit 1; }',
      'matrixtoken="\$(/usr/bin/python3 -I -c ${quoteForAShell(_tokenOfTheAdmission)} "\$admitted/admission.json")" '
          '|| { echo "The admission held no registration token; nothing was sent." >&2; exit 1; }',
      r'/usr/bin/rm -rf -- "$admitted"',
    ],
    // The drive's login keeps this terminal's echo: ssh hands its modes to the far end's terminal, whose own
    // prompts show the e-mail and hide the password. Echo goes off the moment it ends, before the file is opened.
    if (needs.contains('drive'))
      '${sshLine([
        '-t',
        '--',
        driveHost ?? host,
        inTheLoginShell(hostStopCommand(['drive'], email: email)),
      ])} || exit \$?',
    // The forge's certificate request is public, asked of the host before the file is opened; the file's script signs it.
    if (fed.contains('forge-certificate'))
      'request="\$(${sshLine(['-n', '-T', '--', host, '/usr/bin/sudo -n /usr/local/bin/porelo-host-stop --request'])})" '
          '|| { echo "The host gave no certificate request for its forge; nothing was sent." >&2; exit 1; }',
    if (caOut != null && fed.contains('forge-certificate')) 'caout=${quoteForAShell(caOut)}',
    '/usr/bin/stty -echo 2>/dev/null || true',
    // A stop that takes no line still reads a pipe: an empty one.
    '{\n${feed.isEmpty ? ':' : feed}\n} | ${sshLine(['-T', '--', host, stop])}',
  ].join('\n');
  return _inACleanBash(script);
}

/// The command the vault's unlock terminal runs on this desktop for a rented server: the file's master password typed
/// once, here, and the vault passphrase from its entry on a pipe into `porelo vault unlock --passphrase-stdin` as
/// [host], the server's Porelo account. The passphrase reaches no argument, the far end's terminal or this program.
List<String> hostUnlockFeedCommand({
  required String secretsFile,
  required String project,
  required String ssh,
  required List<String> sshOptions,
  required String host,
  String cli = SecretsFile.keepassxcCli,
}) {
  if (!ssh.startsWith('/')) throw const FormatException('ssh is run by its absolute path.');
  if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_-]*@[A-Za-z0-9][A-Za-z0-9.:-]*$').hasMatch(host)) {
    throw FormatException('The server is not named by a valid user and address: $host.');
  }
  final feed = SecretsFile(secretsFile, cli: cli).unlockLine(project: project);
  final pipe = [ssh, ...sshOptions, '-T', '--', host, '/usr/bin/porelo vault unlock --passphrase-stdin'];
  return _inACleanBash(
    [
      "trap '/usr/bin/stty echo 2>/dev/null || true' EXIT",
      'set -o pipefail',
      '/usr/bin/stty -echo 2>/dev/null || true',
      // No login shell at the far end: its profile would run with the pipe on its standard input.
      '{\n$feed\n} | ${pipe.map(quoteForAShell).join(' ')}',
    ].join('\n'),
  );
}

/// Feeds the lasting password to the host as the person's own login, for bring and join terminals.
List<String> hostForgePasswordFeedCommand({
  required String secretsFile,
  required String ssh,
  required List<String> sshOptions,
  required String host,
  String cli = SecretsFile.keepassxcCli,
}) {
  if (!ssh.startsWith('/')) throw const FormatException('ssh is run by its absolute path.');
  if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_-]*@[A-Za-z0-9][A-Za-z0-9.:-]*$').hasMatch(host)) {
    throw const FormatException('The forge password needs the person\'s own host login and address.');
  }
  final pipe = [ssh, ...sshOptions, '-T', '--', host, '/usr/bin/sudo -n /usr/local/sbin/porelo-host-forge-password'];
  final feed = SecretsFile(secretsFile, cli: cli).forgePasswordLine(receiver: pipe);
  return _inACleanBash(
    [
      '/usr/bin/stty -echo 2>/dev/null || true',
      "trap '/usr/bin/stty echo 2>/dev/null || true' EXIT",
      'set -o pipefail',
      feed,
    ].join('\n'),
  );
}

// Neither the caller's startup files nor an inherited trace may run in the shell that holds the secrets.
List<String> _inACleanBash(String script) => [
  '/usr/bin/env',
  '-u',
  'BASH_ENV',
  '-u',
  'ENV',
  '-u',
  'SHELLOPTS',
  '-u',
  'BASHOPTS',
  '/bin/bash',
  '--noprofile',
  '--norc',
  '-c',
  script,
];

/// Prints the admission's registration token in base64, the form `porelo-host-stop` reads; fails where there is none.
const _tokenOfTheAdmission =
    'import base64, json, sys\n'
    't = json.load(open(sys.argv[1]))["secrets"]["registration_token"]\n'
    'assert isinstance(t, str) and t\n'
    'print(base64.b64encode(t.encode()).decode())';
