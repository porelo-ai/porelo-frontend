import 'package:porelo_host/porelo_host.dart';

/// The command the stop's terminal runs on this desktop when the host takes its secrets from the person's file.
///
/// The drive's login, where the host still names it, runs first in a terminal of its own on the host, as
/// [driveHost] (the account, as today's stop). Then the file's lines for [needs], and for [keys], the vault entries
/// `machine.yml` names, go on a pipe into `sudo porelo-host-stop --stdin` as [host]: the master password is typed
/// once, here, and no secret reaches an argument, the far end's terminal or this program.
List<String> hostStopFeedCommand({
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
}) {
  final unknown = needs.where((need) => need != 'drive' && !SecretsFile.stopNeeds.contains(need));
  if (unknown.isNotEmpty) {
    throw FormatException('The host asked for ${unknown.join(', ')}, which the secrets file does not give.');
  }
  final fed = needs.where(SecretsFile.stopNeeds.contains).toList();
  if (fed.isEmpty) throw const FormatException('The host asks for nothing the secrets file gives.');
  // Where the lasting CA's certificate is written, public, once the forge's request is signed.
  if (caOut != null) SecretsFile.checkPath(caOut);
  // The program that receives every secret on its standard input is taken by its path, never by PATH.
  if (!ssh.startsWith('/')) throw const FormatException('ssh is run by its absolute path.');
  final login = RegExp(r'^[A-Za-z_][A-Za-z0-9_-]*@[A-Za-z0-9][A-Za-z0-9.:-]*$');
  for (final each in [host, if (needs.contains('drive')) driveHost ?? host]) {
    if (!login.hasMatch(each)) throw FormatException('The host stop did not name a valid user and address: $each.');
  }
  final feed = SecretsFile(
    secretsFile,
    cli: cli,
  ).stopLines(project: project, needs: fed, keys: fed.contains('keys') ? keys : const []);
  String sshLine(List<String> arguments) => [ssh, ...sshOptions, ...arguments].map(quoteForAShell).join(' ');
  // No login shell at the far end: its profile would run with the pipe on its standard input. `-n`: a sudo that
  // asks a password fails instead of reading one from the pipe.
  final stop = '/usr/bin/sudo -n /usr/local/bin/porelo-host-stop --stdin ${fed.join(' ')}';
  final script = [
    "trap '/usr/bin/stty echo 2>/dev/null || true' EXIT",
    'set -o pipefail',
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
    '{\n$feed\n} | ${sshLine(['-T', '--', host, stop])}',
  ].join('\n');
  // Neither the caller's startup files nor an inherited trace may run in the shell that holds the secrets.
  return [
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
}
