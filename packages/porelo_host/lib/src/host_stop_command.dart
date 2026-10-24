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
  return <String>[
    '/usr/local/bin/porelo-host-stop',
    if (drive) ...['--email', email],
    ...needs,
  ].map((argument) => "'$argument'").join(' ');
}
