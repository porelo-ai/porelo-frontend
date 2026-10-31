import 'host_file_name.dart' show HostFilesRefused;

/// The person's `secrets.kdbx`, opened only by `keepassxc-cli` in a terminal on this desktop, and the validation
/// shared by encrypted-storage references and legacy rental recovery.
///
/// This builds the script that runs there and holds no secret itself: the master password is typed into that
/// terminal once and reaches `keepassxc-cli` on standard input only, and every entry stays inside the script's
/// own shell.
class SecretsFile {
  /// Names the file and the `keepassxc-cli` that opens it.
  SecretsFile(this.file, {this.cli = keepassxcCli}) {
    checkPath(file);
    checkPath(cli);
  }

  /// The packaged `keepassxc-cli`, run by its absolute path.
  static const keepassxcCli = '/usr/bin/keepassxc-cli';

  /// The file, an absolute path on this desktop.
  final String file;

  /// The `keepassxc-cli` that opens it.
  final String cli;

  /// Refuses unsafe legacy rental identifiers.
  static void checkHost(String host) {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(host) || host == '.' || host == '..') {
      throw const HostFilesRefused('A project name holds only letters, digits, ".", "_" and "-".');
    }
  }

  /// Refuses a path that cannot be passed as one plain shell word.
  static void checkPath(String value) {
    if (!value.startsWith('/') || value.length < 2 || RegExp(r'[^A-Za-z0-9 /._:@%+=,-]').hasMatch(value)) {
      throw const FormatException('A plain absolute encrypted-storage path is required.');
    }
  }

  /// Refuses unsafe vault entry names.
  static void checkKeyName(String name) {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(name)) {
      throw const HostFilesRefused('A vault entry name holds only letters, digits, ".", "_" and "-".');
    }
  }

  static String _word(String value) => "'$value'";

  /// The current interface instance's central transfer entry below the root group.
  static const centralTransferToken = 'forge-central-token';

  /// Checks the local token before SSH starts and builds its encoded stdin line.
  ///
  /// Both scripts run in one terminal shell; no secret is returned to Dart.
  ({String check, String feed}) projectTransferScripts() => (
    check: [
      // The transfer owns terminal echo and signal cleanup through SSH completion.
      ..._opened.skip(_shellStart.length),
      _listEntries,
      ..._requireEntries([centralTransferToken]),
      ..._readEntry(centralTransferToken, 'transfer_token'),
      r'''if [[ "$transfer_token" =~ [[:space:][:cntrl:]] ]]; then echo "The central forge token must hold one nonempty line; nothing was sent." >&2; exit 1; fi''',
      r'''transfer_encoded="$(printf '%s' "$transfer_token" | /usr/bin/base64 -w0)" || { echo "The central token could not be encoded; nothing was sent." >&2; exit 1; }''',
      'unset MASTER entries',
    ].join('\n'),
    feed:
        "printf '%s %s\\n' '$centralTransferToken' "
        r'"$transfer_encoded"',
  );

  static List<String> _readEntry(String entry, String variable) => [
    '$variable="\$(kp show -s -a password "\$file" ${_word(entry)} 2>/dev/null && printf \'.\')" || { '
        'echo "$entry could not be read; nothing was sent. Open it in KeePassXC and replace its password value." >&2; exit 1; }',
    '$variable="\${$variable%.}"; $variable="\${$variable%\$\'\\n\'}"',
    'if [ -z "\$$variable" ]; then echo "$entry is empty; nothing was sent. Set its password value in KeePassXC." >&2; exit 1; fi',
  ];

  static const _listEntries =
      r'''entries="$(LC_ALL=C.UTF-8 LANGUAGE= kp ls -q -R -f "$file")" || { echo "The secrets file could not be listed; nothing was sent." >&2; exit 1; }''';

  static List<String> _requireEntries(List<String> required) => [
    if (required.isNotEmpty) ...[
      'missing=no',
      for (final entry in required) ...[
        "if [[ \$'\\n'\"\$entries\"\$'\\n' != *\$'\\n'${_word(entry)}\$'\\n'* ]]; then",
        '  echo "\$file has no entry $entry; nothing was sent. Add it in KeePassXC under that entry name." >&2',
        '  missing=yes',
        'fi',
      ],
      r'[ "$missing" = no ] || exit 1',
      'unset missing',
    ],
  ];

  /// The script's start: no echo, and the master password asked and checked against the file.
  List<String> get _opened => [
    ..._shellStart,
    'cli=${_word(cli)}',
    'file=${_word(file)}',
    _kp,
    // A missing command line is said before any password is asked, never taken for a wrong password.
    'cli_found=\$(command -v -- "\$cli" || true)',
    'if ! [ -f "\$cli_found" ] || ! [ -x "\$cli_found" ]; then echo "KeePassXC\'s command line is not installed here (\$cli), so \$file cannot be opened; nothing was sent. Install it in a terminal of your own: sudo apt install keepassxc-minimal" >&2; exit 1; fi',
    'unset cli_found',
    // A file that cannot be read is said as such, never asked about three times as a wrong password.
    r'if ! [ -r "$file" ]; then echo "$file cannot be read; nothing was sent." >&2; exit 1; fi',
    // A mistyped password is asked again, three times at most; an empty one or the end of input ends it at once.
    'for try in 1 2 3; do',
    r'  IFS= read -rs -p "The master password of $file: " MASTER; echo >&2',
    r'  if [ -z "$MASTER" ]; then echo "A master password cannot be empty; nothing was sent." >&2; exit 1; fi',
    r'  if kp ls "$file" >/dev/null 2>&1; then break; fi',
    r'  if [ "$try" = 3 ]; then echo "$file did not open with that password three times; nothing was sent." >&2; exit 1; fi',
    r'  echo "$file did not open with that password; type it again." >&2',
    'done',
  ];

  // No echo from the first byte, and none of the caller's tracing: neither may draw a secret on the terminal.
  static const _shellStart = [
    '/usr/bin/stty -echo 2>/dev/null || true',
    "trap '/usr/bin/stty echo 2>/dev/null || true' EXIT",
    'set +x',
    'set -euo pipefail',
    'umask 077',
  ];

  // Every call reads the master password from standard input; the builtin printf runs no other program.
  static const _kp = r'''kp() { printf '%s\n' "$MASTER" | "$cli" "$@"; }''';
}
