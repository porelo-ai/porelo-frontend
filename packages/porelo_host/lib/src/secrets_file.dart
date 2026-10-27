import 'host_files.dart' show HostFilesRefused;

/// The person's `secrets.kdbx`, opened only by `keepassxc-cli` in a terminal on this desktop.
///
/// This builds the script that runs there and holds no secret itself: the master password is typed into that
/// terminal once and reaches `keepassxc-cli` on standard input only, and every entry stays inside the script's
/// own shell. The interface reads back nothing but a public key.
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

  /// The `keepassxc-cli` to run.
  final String cli;

  /// The entry of a host's own WireGuard key, below the root group.
  static String hostKey(String project) => 'hosts/$project/wireguard';

  /// The entry of a host's vault passphrase, below the root group.
  static String vaultPassphrase(String project) => 'hosts/$project/vault-passphrase';

  /// Refuses a path a shell would read as more than one quoted word.
  static void checkPath(String value) {
    if (!value.startsWith('/') || value.length < 2 || RegExp(r'[^A-Za-z0-9 /._:@%+=,-]').hasMatch(value)) {
      throw const FormatException(
        'The secrets file needs a plain absolute path, without quotes, shell characters or line breaks.',
      );
    }
  }

  static String _word(String value) => "'$value'";

  /// The needs a host's stop takes on standard input, as `porelo-host-stop --stdin` names them.
  static const stopNeeds = <String>{'vault', 'vault-new', 'wireguard', 'keys'};

  /// The entry of a vault entry's file for [project]'s host, its bytes base64 in the password field.
  static String vaultKey(String project, String name) => 'hosts/$project/keys/$name';

  /// The script that writes the stop's lines for [needs], one `<need> [<name>] <base64>` per secret, to standard output,
  /// which is the pipe to the host's `porelo-host-stop --stdin`; `keys` brings every entry under
  /// `hosts/<project>/keys/`.
  ///
  /// Every entry is read before the first line is written, so a missing one sends nothing and is named.
  String stopLines({required String project, required List<String> needs}) {
    _checkProject(project);
    for (final need in needs) {
      if (!stopNeeds.contains(need)) {
        throw FormatException('The host asked for "$need", which the secrets file does not give.');
      }
    }
    if (needs.toSet().length != needs.length) throw const FormatException('The host named a need twice.');
    final reads = <String>[];
    final writes = <String>[];
    var index = 0;
    void entry(String line, String path, {bool base64 = false}) {
      final variable = 'v${index++}';
      reads.add('$variable="\$(get ${_word(path)})"');
      if (base64) {
        // Kept base64 already: checked, and sent as it is.
        reads.add(
          'if ! [[ "\$$variable" =~ ^[A-Za-z0-9+/]+={0,2}\$ ]]; then '
          'echo "${path.replaceAll('"', '')} is not base64; nothing was sent." >&2; exit 1; fi',
        );
        writes.add("printf '%s %s\\n' ${_word(line)} \"\$$variable\"");
      } else {
        writes.add("printf '%s %s\\n' ${_word(line)} \"\$(printf '%s' \"\$$variable\" | /usr/bin/base64 -w0)\"");
      }
    }

    for (final need in needs) {
      switch (need) {
        case 'vault' || 'vault-new':
          entry(need, vaultPassphrase(project));
        case 'wireguard':
          entry(need, hostKey(project));
        case 'keys':
          final group = _word('hosts/$project/keys');
          // Every entry of the group, each name checked and each value kept base64 already.
          reads.addAll([
            'keys=()',
            'names="\$(kp ls "\$file" $group 2>/dev/null || true)"',
            'while IFS= read -r name; do',
            '  case "\$name" in ""|*/) continue;; esac',
            '  if ! [[ "\$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*\$ ]]; then '
                'echo "\$file has an entry named \$name under hosts/$project/keys; nothing was sent." >&2; exit 1; fi',
            '  value="\$(get "hosts/$project/keys/\$name")"',
            '  if ! [[ "\$value" =~ ^[A-Za-z0-9+/]+={0,2}\$ ]]; then '
                'echo "hosts/$project/keys/\$name is not base64; nothing was sent." >&2; exit 1; fi',
            '  keys+=("key \$name \$value")',
            r'''done < <(printf '%s
' "$names")''',
            'if [ \${#keys[@]} -eq 0 ]; then '
                'echo "\$file keeps no vault entry under hosts/$project/keys; nothing was sent." >&2; exit 1; fi',
          ]);
          writes.add(r'''for line in "${keys[@]}"; do printf '%s
' "$line"; done''');
      }
    }
    return [
      '/usr/bin/stty -echo 2>/dev/null || true',
      "trap '/usr/bin/stty echo 2>/dev/null || true' EXIT",
      'set +x',
      'set -euo pipefail',
      'umask 077',
      'cli=${_word(cli)}',
      'file=${_word(file)}',
      r'kp() { printf'
          " '%s\\n' "
          r'"$MASTER" | "$cli" "$@"; }',
      r'''get() { local value; value="$(kp show -s -a password "$file" "$1" 2>/dev/null || true)"; if [ -z "$value" ]; then echo "$file has no entry $1; nothing was sent." >&2; return 1; fi; printf '%s' "$value"; }''',
      r'IFS= read -rs -p "The master password of $file: " MASTER; echo >&2',
      r'if [ -z "$MASTER" ]; then echo "A master password cannot be empty; nothing was sent." >&2; exit 1; fi',
      r'if ! kp ls "$file" >/dev/null 2>&1; then echo "$file did not open with that password; nothing was sent." >&2; exit 1; fi',
      ...reads,
      ...writes,
      'unset MASTER ${[for (var i = 0; i < index; i++) 'v$i'].join(' ')}${needs.contains('keys') ? ' keys value' : ''}',
    ].join('\n');
  }

  static void _checkProject(String project) {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(project)) {
      throw const HostFilesRefused('A project name holds only letters, digits, ".", "_" and "-".');
    }
  }

  /// The script that makes the file where [create] says so, gives [project]'s host a WireGuard key and a vault
  /// passphrase where it has none, and writes only the key's public half to [publicKeyOut], `0600`.
  ///
  /// A key in [migrateKeyFrom], the host's key from before the file, is taken into the file and that file then
  /// removed. A run that cannot open the file writes nothing.
  String prepareHost({
    required String project,
    required bool create,
    required String publicKeyOut,
    String? migrateKeyFrom,
    Map<String, String> keys = const {},
  }) {
    _checkProject(project);
    checkPath(publicKeyOut);
    if (migrateKeyFrom != null) checkPath(migrateKeyFrom);
    for (final entry in keys.entries) {
      if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(entry.key)) {
        throw const HostFilesRefused('A vault entry name holds only letters, digits, ".", "_" and "-".');
      }
      checkPath(entry.value);
    }
    final key = _word(hostKey(project));
    final passphrase = _word(vaultPassphrase(project));
    final group = _word('hosts/$project');
    final drive = migrateKeyFrom == null ? null : _word(migrateKeyFrom);
    return [
      // No echo from the first byte, and none of the caller's tracing: neither may draw a secret on the terminal.
      '/usr/bin/stty -echo 2>/dev/null || true',
      "trap '/usr/bin/stty echo 2>/dev/null || true' EXIT",
      'set +x',
      'set -euo pipefail',
      'umask 077',
      'cli=${_word(cli)}',
      'file=${_word(file)}',
      'out=${_word(publicKeyOut)}',
      // Every call reads the master password from standard input; the builtin printf runs no other program.
      r'kp() { printf'
          " '%s\\n' "
          r'"$MASTER" | "$cli" "$@"; }',
      // A WireGuard private key is one whose public half wg can derive.
      r'''valid() { local half; half="$(printf '%s\n' "$1" | /usr/bin/wg pubkey 2>/dev/null)" && [ -n "$half" ]; }''',
      if (create) ...[
        r'if [ -e "$file" ]; then echo "$file exists already; name it instead of making it anew." >&2; exit 65; fi',
        r'IFS= read -rs -p "A new master password for $file: " MASTER; echo >&2',
        r'IFS= read -rs -p "The same once more: " AGAIN; echo >&2',
        r'if [ "$MASTER" != "$AGAIN" ]; then echo "The two did not match; nothing was made." >&2; exit 1; fi',
        'unset AGAIN',
      ] else
        r'IFS= read -rs -p "The master password of $file: " MASTER; echo >&2',
      r'if [ -z "$MASTER" ]; then echo "A master password cannot be empty; nothing was changed." >&2; exit 1; fi',
      // A vault entry's file is outside input: checked before anything changes.
      for (final file in keys.values)
        'if [ -L ${_word(file)} ] || [ ! -f ${_word(file)} ]; then '
            'echo "${file.replaceAll('"', '')} is not a plain file; nothing was changed." >&2; exit 1; fi',
      // The drive is read before the file is made or changed, so a refusal leaves both as they were.
      if (drive != null) ...[
        // The drive's copy is outside input: a link or a key wg cannot read is refused, and nothing is changed.
        'if [ -L $drive ]; then echo "The drive\'s wireguard.key is a link; nothing was changed." >&2; exit 1; fi',
        'if [ -e $drive ] && [ ! -f $drive ]; then echo "The drive\'s wireguard.key is not a file; nothing was changed." >&2; exit 1; fi',
        'if [ -f $drive ]; then old="\$(/usr/bin/tr -d \'[:space:]\' < $drive)"; '
            'if ! valid "\$old"; then echo "The drive\'s wireguard.key is no WireGuard key; nothing was changed." >&2; exit 1; fi; '
            'else old=""; fi',
      ],

      if (create) ...[
        r'/usr/bin/mkdir -p "$(/usr/bin/dirname "$file")"',
        r'printf'
            " '%s\\n%s\\n' "
            r'"$MASTER" "$MASTER" | "$cli" db-create -p "$file" >/dev/null',
        'kp mkdir "\$file" ${_word('shared')} >/dev/null',
        'kp mkdir "\$file" ${_word('hosts')} >/dev/null',
      ] else ...[
        r'if ! kp ls "$file" >/dev/null 2>&1; then echo "$file did not open with that password; nothing was changed." >&2; exit 1; fi',
        'kp ls "\$file" ${_word('hosts')} >/dev/null 2>&1 || kp mkdir "\$file" ${_word('hosts')} >/dev/null',
      ],
      'kp ls "\$file" $group >/dev/null 2>&1 || kp mkdir "\$file" $group >/dev/null',
      'private="\$(kp show -s -a password "\$file" $key 2>/dev/null || true)"',
      'if [ -n "\$private" ]; then :',
      // A copy still on the drive goes only when it is the file's own key; another key for the host stops it all.
      if (drive != null)
        '  if [ -n "\$old" ] && [ "\$old" != "\$private" ]; then '
            'echo "The drive holds another key for this server than your secrets file; nothing was changed." >&2; exit 1; fi',
      'elif [ -n "\${old:-}" ]; then private="\$old"; '
          '{ printf \'%s\\n%s\\n\' "\$MASTER" "\$private"; } | "\$cli" add -p "\$file" $key >/dev/null',
      'else private="\$(/usr/bin/wg genkey)"; '
          '{ printf \'%s\\n%s\\n\' "\$MASTER" "\$private"; } | "\$cli" add -p "\$file" $key >/dev/null',
      'fi',
      // Read back before anything is removed: the file must hold the key that is used.
      'if [ "\$(kp show -s -a password "\$file" $key 2>/dev/null)" != "\$private" ] || ! valid "\$private"; then '
          'echo "The secrets file does not hold a WireGuard key for this server; nothing was removed." >&2; exit 1; fi',
      if (drive != null) 'if [ -n "\$old" ]; then /usr/bin/rm -f $drive; fi',
      'kp show "\$file" $passphrase >/dev/null 2>&1 || kp add -g -L 32 "\$file" $passphrase >/dev/null',
      if (keys.isNotEmpty)
        'kp ls "\$file" ${_word('hosts/$project/keys')} >/dev/null 2>&1 || '
            'kp mkdir "\$file" ${_word('hosts/$project/keys')} >/dev/null',
      // A vault entry's file, kept base64; one already kept under that name is replaced only by the same bytes.
      for (final entry in keys.entries) ...[
        'value="\$(/usr/bin/base64 -w0 < ${_word(entry.value)})"',
        'have="\$(kp show -s -a password "\$file" ${_word(vaultKey(project, entry.key))} 2>/dev/null || true)"',
        'if [ -z "\$have" ]; then { printf \'%s\\n%s\\n\' "\$MASTER" "\$value"; } | '
            '"\$cli" add -p "\$file" ${_word(vaultKey(project, entry.key))} >/dev/null; '
            'elif [ "\$have" != "\$value" ]; then echo "Your secrets file keeps another ${entry.key} for this server; '
            'remove it there to take the new one." >&2; exit 1; fi',
      ],
      r'''pub="$(printf '%s\n' "$private" | /usr/bin/wg pubkey)"''',
      r'if [ -z "$pub" ]; then echo "wg gave no public key; nothing was written." >&2; exit 1; fi',
      r'''printf '%s\n' "$pub" > "$out.new"''',
      r'/usr/bin/mv "$out.new" "$out"',
      'unset MASTER private pub old value have',
      r'echo "The secrets file is ready."',
    ].join('\n');
  }
}
