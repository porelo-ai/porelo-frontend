/// What ssh said, in words a person can act on.
///
/// A machine that closes a new connection before login says only `Connection closed by <address>` or
/// `kex_exchange_identification: ... Connection reset`. sshd does that for a while after a few failed
/// logins, or bare connections, from one address; a machine restarting says the same. So this says to
/// wait, and does not say which it was. Only those lines, whole: a line naming another fault, such as a
/// banner that is no ssh's, stays ssh's own. Null stays null.
String? sshRefusalWords(String? said) {
  if (said == null) return null;
  final closed = RegExp(
    r'^(The SSH connection stopped: )?(kex_exchange_identification: (read: )?)?Connection (closed|reset) by [^\n]*$',
    caseSensitive: false,
  ).hasMatch(said.trim());
  final bare = RegExp(
    r'^(The SSH connection stopped: )?kex_exchange_identification: (read: )?Connection (closed|reset)[^\n]*$',
    caseSensitive: false,
  ).hasMatch(said.trim());
  if (!closed && !bare) return said;
  return 'The machine closed the connection before login. A machine does this for about half a minute after a '
      'few failed tries from one address, and while it restarts. Wait a minute and try again; if it goes on, '
      'look at the machine.';
}

/// What to keep of ssh's lines when none is known to mean something else: the last, or, where the last
/// says only that the connection closed, the fault said before it with it. A warning is not a fault.
String? sshLastWords(List<String> said) {
  final lines = [
    for (final line in said)
      if (line.trim().isNotEmpty) line.trim(),
  ];
  if (lines.isEmpty) return null;
  final closes = RegExp(r'^Connection (closed|reset) by ', caseSensitive: false).hasMatch(lines.last);
  if (!closes) return lines.last;
  final faults = [
    for (final line in lines)
      if (!line.startsWith('Warning:') && !line.startsWith('**')) line,
  ];
  return faults.join(' ');
}
