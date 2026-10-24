/// Whether [email] is a plain address safe to quote in the host login command.
bool isHostDriveEmail(String email) =>
    RegExp(r'^[A-Za-z0-9][A-Za-z0-9._+-]*@[A-Za-z0-9]+(?:[.-][A-Za-z0-9]+)*\.[A-Za-z]{2,}$').stringMatch(email) ==
    email;

/// Only the steps named by the host, with secrets left to their own terminal prompts.
String hostStopCommand(List<String> needs, {String email = ''}) {
  if (needs.isEmpty || needs.any((need) => !const {'drive', 'vault-new', 'vault'}.contains(need))) {
    throw const FormatException('The host named an unsupported terminal step.');
  }
  final drive = needs.contains('drive');
  if (drive && !isHostDriveEmail(email)) {
    throw const FormatException('Enter a plain Tresorit e-mail address with no spaces, quotes or shell characters.');
  }
  final vault = needs.contains('vault-new') || needs.contains('vault');
  final commands = <String>[
    r'export XDG_RUNTIME_DIR=/run/user/$(id -u)',
    if (drive) ...<String>[
      r"printf '%s\n' 'The one-time code will show as you type it.'",
      "tresorit-cli login --email '$email' --password-on-stdin",
      vault
          ? r"printf '%s\n' 'Logged in to Tresorit; the vault comes next.'"
          : r"printf '%s\n' 'Logged in to Tresorit; close this terminal to continue host setup.'",
    ],
    if (needs.contains('vault-new')) ...<String>[
      'porelo vault init',
      r"printf '%s\n' 'Vault initialized; close this terminal to continue host setup.'",
    ] else if (needs.contains('vault')) ...<String>[
      'porelo vault unlock',
      r"printf '%s\n' 'Vault unlocked; close this terminal to continue host setup.'",
    ],
  ];
  return commands.join(' && ');
}
