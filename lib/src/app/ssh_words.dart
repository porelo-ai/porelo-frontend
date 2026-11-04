/// What ssh said, in words a person can act on.
///
/// A machine that closes a new connection before login says only `Connection closed by <address>` or
/// `kex_exchange_identification: ... Connection reset`. sshd does that for a while after a few failed
/// logins, or bare connections, from one address; a machine restarting says the same. So this says to
/// wait, and does not say which it was. Null stays null; anything else is ssh's own words.
String? sshRefusalWords(String? said) {
  if (said == null) return null;
  final closed = RegExp(
    r'kex_exchange_identification|Connection (closed|reset) by',
    caseSensitive: false,
  ).hasMatch(said);
  if (!closed) return said;
  return 'The machine closed the connection before login. A machine does this for about half a minute after a '
      'few failed tries from one address, and while it restarts. Wait a minute and try again.';
}
