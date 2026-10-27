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
  }) {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(project)) {
      throw const HostFilesRefused('A project name holds only letters, digits, ".", "_" and "-".');
    }
    checkPath(publicKeyOut);
    if (migrateKeyFrom != null) checkPath(migrateKeyFrom);
    final key = _word(hostKey(project));
    final passphrase = _word(vaultPassphrase(project));
    final group = _word('hosts/$project');
    return [
      'set -euo pipefail',
      'umask 077',
      'cli=${_word(cli)}',
      'file=${_word(file)}',
      'out=${_word(publicKeyOut)}',
      // Every call reads the master password from standard input; the builtin printf runs no other program.
      r'kp() { printf'
          " '%s\\n' "
          r'"$MASTER" | "$cli" "$@"; }',
      if (create) ...[
        r'if [ -e "$file" ]; then echo "$file exists already; name it instead of making it anew." >&2; exit 65; fi',
        r'IFS= read -rs -p "A new master password for $file: " MASTER; echo >&2',
        r'IFS= read -rs -p "The same once more: " AGAIN; echo >&2',
        r'if [ "$MASTER" != "$AGAIN" ]; then echo "The two did not match; nothing was made." >&2; exit 1; fi',
        'unset AGAIN',
        r'mkdir -p "$(dirname "$file")"',
        r'printf'
            " '%s\\n%s\\n' "
            r'"$MASTER" "$MASTER" | "$cli" db-create -p "$file" >/dev/null',
        'kp mkdir "\$file" ${_word('shared')} >/dev/null',
        'kp mkdir "\$file" ${_word('hosts')} >/dev/null',
      ] else ...[
        r'IFS= read -rs -p "The master password of $file: " MASTER; echo >&2',
        r'if ! kp ls "$file" >/dev/null 2>&1; then echo "$file did not open with that password; nothing was changed." >&2; exit 1; fi',
        'kp ls "\$file" ${_word('hosts')} >/dev/null 2>&1 || kp mkdir "\$file" ${_word('hosts')} >/dev/null',
      ],
      'kp ls "\$file" $group >/dev/null 2>&1 || kp mkdir "\$file" $group >/dev/null',
      'if private="\$(kp show -s -a password "\$file" $key 2>/dev/null)" && [ -n "\$private" ]; then :',
      if (migrateKeyFrom != null)
        'elif [ -f ${_word(migrateKeyFrom)} ]; then private="\$(tr -d \'[:space:]\' < ${_word(migrateKeyFrom)})"; '
            '{ printf \'%s\\n%s\\n\' "\$MASTER" "\$private"; } | "\$cli" add -p "\$file" $key >/dev/null; '
            'rm -f ${_word(migrateKeyFrom)}',
      'else private="\$(wg genkey)"; '
          '{ printf \'%s\\n%s\\n\' "\$MASTER" "\$private"; } | "\$cli" add -p "\$file" $key >/dev/null',
      'fi',
      'kp show "\$file" $passphrase >/dev/null 2>&1 || kp add -g -L 32 "\$file" $passphrase >/dev/null',
      // Read through a pipe and checked: a public key that came out empty is refused, never written.
      r'pub="$(wg pubkey <<<"$private")"',
      r'if [ -z "$pub" ]; then echo "wg gave no public key; nothing was written." >&2; exit 1; fi',
      r'''printf '%s\n' "$pub" > "$out.new"''',
      r'mv "$out.new" "$out"',
      'unset MASTER private pub',
      r'echo "The secrets file is ready."',
    ].join('\n');
  }
}
