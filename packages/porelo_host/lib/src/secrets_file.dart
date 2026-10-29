import 'dart:io';

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

  /// What to say where [cli] is not there, before a terminal asks a master password it cannot use; null where it
  /// is. The interface's package brings it; a build run from its sources does not.
  static String? missingCli([String cli = keepassxcCli]) => File(cli).existsSync() ? null : cliMissing(cli);

  /// What is said where [cli] is not there.
  static String cliMissing([String cli = keepassxcCli]) =>
      'KeePassXC\'s command line is not installed here ($cli), so the secrets file cannot be opened. Install it, '
      'in a terminal of your own: $installCli';

  /// What installs [keepassxcCli], to be run by the person in a terminal of their own.
  static const installCli = 'sudo apt install keepassxc-minimal';

  /// The file, an absolute path on this desktop.
  final String file;

  /// The `keepassxc-cli` to run.
  final String cli;

  /// The entry of a host's own WireGuard key, below the root group.
  static String hostKey(String host) {
    checkHost(host);
    return 'hosts/$host/wireguard';
  }

  /// The entry of a project's vault passphrase, below the root group.
  static String vaultPassphrase(String project) {
    _checkProject(project);
    return 'projects/$project/vault-passphrase';
  }

  /// Refuses a host name that is not a lowercase DNS label.
  static void checkHost(String host) {
    if (!RegExp(r'^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$').hasMatch(host)) {
      throw const HostFilesRefused(
        'A host name has 1 to 63 lowercase letters, digits or hyphens, with a letter or digit at each end.',
      );
    }
  }

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
  static const stopNeeds = <String>{
    'vault',
    'vault-new',
    'wireguard',
    'keys',
    'forge-central-token',
    'forge-certificate',
  };

  /// The host's lasting CA key, PEM kept base64.
  static String forgeCaKey(String host) {
    checkHost(host);
    return 'hosts/$host/forge-ca-key';
  }

  /// The host's lasting CA certificate, PEM kept base64.
  static String forgeCa(String host) {
    checkHost(host);
    return 'hosts/$host/forge-ca';
  }

  /// The forge's address and name on the VPN, which every host's forge certificate names, set here and never taken
  /// from the host's request.
  static const forgeAddress = '10.73.0.1';

  /// The forge's name, which the VPN step resolves to [forgeAddress] on this desktop.
  static const forgeName = 'forge.porelo.internal';

  // Only the public request's key counts; its subject and extensions must not broaden the certificate's scope.
  static List<String> _forgeCertificate(String host) => <String>[
    'cakey64="\$(kp show -s -a password "\$file" ${_word(forgeCaKey(host))} 2>/dev/null || true)"',
    'ca64="\$(kp show -s -a password "\$file" ${_word(forgeCa(host))} 2>/dev/null || true)"',
    'if { [ -z "\$cakey64" ] && [ -n "\$ca64" ]; } || { [ -n "\$cakey64" ] && [ -z "\$ca64" ]; }; then '
        'echo "\$file keeps only one of ${forgeCaKey(host)} and ${forgeCa(host)}; nothing was sent." >&2; exit 1; fi',
    // Made once, in this terminal, the first time a host asks: ten years, held to the VPN's names and addresses.
    r'''if [ -z "$cakey64" ]; then''',
    r'''  cakey="$(/usr/bin/openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 2>/dev/null)"''',
    r'''  ca="$(/usr/bin/openssl req -x509 -new -key <(printf '%s\n' "$cakey") -subj '/CN=Porelo forge CA' -days 3650 -addext 'basicConstraints=critical,CA:TRUE,pathlen:0' -addext 'keyUsage=critical,keyCertSign,cRLSign' -addext 'nameConstraints=critical,permitted;DNS:porelo.internal,permitted;IP:10.73.0.0/255.255.255.0')"''',
    '  ensure_group ${_word('hosts/$host')}',
    '  { printf \'%s\\n%s\\n\' "\$MASTER" "\$(printf \'%s\\n\' "\$cakey" | /usr/bin/base64 -w0)"; } | '
        '"\$cli" add -p "\$file" ${_word(forgeCaKey(host))} >/dev/null',
    '  { printf \'%s\\n%s\\n\' "\$MASTER" "\$(printf \'%s\\n\' "\$ca" | /usr/bin/base64 -w0)"; } | '
        '"\$cli" add -p "\$file" ${_word(forgeCa(host))} >/dev/null',
    r'''  echo "A lasting CA for your forges is made, and kept in your secrets file." >&2''',
    r'''else''',
    r'''  cakey="$(printf '%s' "$cakey64" | /usr/bin/base64 -d)"; ca="$(printf '%s' "$ca64" | /usr/bin/base64 -d)"''',
    r'''fi''',
    r'''unset cakey64 ca64''',
    r'''if ! printf '%s\n' "${request:-}" | /usr/bin/openssl req -noout -verify >/dev/null 2>&1; then echo "The host gave no certificate request it signed itself; nothing was sent." >&2; exit 1; fi''',
    r'''cert="$(/usr/bin/openssl x509 -req -in <(printf '%s\n' "$request") -subj '/CN=forge.porelo.internal' -CA <(printf '%s\n' "$ca") -CAkey <(printf '%s\n' "$cakey") -days 365 -set_serial "0x$(/usr/bin/openssl rand -hex 16)" -extfile <(printf '%s\n' 'subjectAltName=IP:10.73.0.1,DNS:forge.porelo.internal' 'basicConstraints=critical,CA:FALSE' 'extendedKeyUsage=serverAuth') 2>/dev/null)"''',
    r'''eforge="$(printf '%s\n%s\n' "$cert" "$ca" | /usr/bin/base64 -w0)"''',
    r'''if [ -z "$cert" ] || ! [[ "$eforge" =~ $b64 ]]; then echo "The forge's certificate could not be signed; nothing was sent." >&2; exit 1; fi''',
    // The CA's certificate, public, for this desktop to trust: where the stop's terminal names a file for it.
    r'''if [ -n "${caout:-}" ]; then printf '%s\n' "$ca" > "$caout"; fi''',
  ];

  /// The entry of the central forge's token, which every host of the person shares.
  static const centralForgeToken = 'shared/forge-central-token';

  /// The entry of [project]'s vault entry file, its bytes base64 in the password field.
  static String vaultKey(String project, String name) {
    _checkProject(project);
    checkKeyName(name);
    return 'projects/$project/keys/$name';
  }

  /// The script that writes the stop's lines for [needs], one `<need> <base64>` per secret and `key <name> <base64>`
  /// per name in [keys], to standard output, which is the pipe to the host's `porelo-host-stop --stdin`.
  ///
  /// [keys] are the vault entries `machine.yml` names, none or more; another entry the file keeps for the project is
  /// never sent. Every entry is read and encoded before the first line is written, so a missing one sends nothing
  /// and is named.
  String stopLines({
    required String host,
    required String project,
    required List<String> needs,
    List<String> keys = const [],
  }) {
    checkHost(host);
    _checkProject(project);
    if (needs.isEmpty) throw const FormatException('The host asked for nothing the secrets file gives.');
    for (final need in needs) {
      if (!stopNeeds.contains(need)) {
        throw FormatException('The host asked for "$need", which the secrets file does not give.');
      }
    }
    if (needs.toSet().length != needs.length) throw const FormatException('The host named a need twice.');
    if (needs.contains('vault') && needs.contains('vault-new')) {
      throw const FormatException('The host asked for a new vault and for an open one at once.');
    }
    if (keys.isNotEmpty && !needs.contains('keys')) {
      throw const FormatException('The host did not ask for the files of its vault entries.');
    }
    // The host takes `keys` with no line only beside a new vault, for a machine without vault entries.
    if (needs.contains('keys') && keys.isEmpty && !needs.contains('vault-new')) {
      throw const FormatException(
        'The host asks for the files of its vault entries, and this setup names none. Choose them on the drive\'s '
        'step and put the server on again.',
      );
    }
    for (final name in keys) {
      checkKeyName(name);
    }
    if (keys.toSet().length != keys.length) throw const FormatException('A vault entry is named twice.');
    final reads = <String>[];
    final writes = <String>[];
    final variables = <String>[];
    var index = 0;
    for (final need in needs) {
      final path = switch (need) {
        'vault' || 'vault-new' => vaultPassphrase(project),
        'wireguard' => hostKey(host),
        'forge-central-token' => centralForgeToken,
        _ => null,
      };
      if (path != null) {
        final variable = 'v${index++}';
        variables.addAll([variable, 'e$variable']);
        reads.addAll([
          '$variable="\$(get ${_word(path)})"',
          // Encoded here, before any line goes: a failure later would leave the host a part of its feed.
          'e$variable="\$(printf \'%s\' "\$$variable" | /usr/bin/base64 -w0)"',
          'if [ -z "\$e$variable" ] || ! [[ "\$e$variable" =~ \$b64 ]]; then '
              'echo "$path did not encode; nothing was sent." >&2; exit 1; fi',
        ]);
        writes.add("printf '%s %s\\n' ${_word(need)} \"\$e$variable\"");
      } else if (need == 'forge-certificate') {
        reads.addAll(_forgeCertificate(host));
        variables.addAll(['cakey', 'ca', 'cert', 'eforge']);
        writes.add(r'''printf 'forge-certificate %s\n' "$eforge"''');
      } else {
        // Each entry kept base64 already, by prepareHost: checked as such, and sent as it is.
        for (final name in keys) {
          final variable = 'v${index++}';
          variables.add(variable);
          reads.addAll([
            '$variable="\$(get ${_word(vaultKey(project, name))})"',
            'if [ -z "\$$variable" ] || ! [[ "\$$variable" =~ \$b64 ]]; then '
                'echo "${vaultKey(project, name)} is not base64; nothing was sent." >&2; exit 1; fi',
          ]);
          writes.add("printf 'key %s %s\\n' ${_word(name)} \"\$$variable\"");
        }
      }
    }
    return [
      ..._opened,
      ..._migrateEntries(host, project),
      // Whole groups of four, padded at the end only: what the host decodes as it stands.
      r"b64='^([A-Za-z0-9+/]{4})*([A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$'",
      ...reads,
      ...writes,
      'unset MASTER ${variables.join(' ')}',
    ].join('\n');
  }

  /// The script that writes [project]'s vault passphrase as one line to standard output, which is the pipe to the
  /// host's `porelo vault unlock --passphrase-stdin`, after the file's master password is typed once. A file that
  /// does not open, or has no such entry, writes nothing.
  String unlockLine({required String project}) {
    _checkProject(project);
    return [
      ..._opened,
      'v="\$(get ${_word(vaultPassphrase(project))})"',
      r'''printf '%s\n' "$v"''',
      'unset MASTER v',
    ].join('\n');
  }

  /// The script's start: no echo, `get` for an entry, and the master password asked and checked against the file.
  List<String> get _opened => [
    ..._shellStart,
    'cli=${_word(cli)}',
    'file=${_word(file)}',
    _kp,
    r'''get() { local value; value="$(kp show -s -a password "$file" "$1" 2>/dev/null || true)"; if [ -z "$value" ]; then echo "$file has no entry $1; nothing was sent." >&2; return 1; fi; printf '%s' "$value"; }''',
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

  /// Refuses a vault entry name the file's group, `machine.yml` and the host's stop would not all take.
  static void checkKeyName(String name) {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(name)) {
      throw const HostFilesRefused('A vault entry name holds only letters, digits, ".", "_" and "-".');
    }
  }

  static void _checkProject(String project) {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(project)) {
      throw const HostFilesRefused('A project name holds only letters, digits, ".", "_" and "-".');
    }
  }

  // A copy is read back before its source is removed, so a failed or incomplete write cannot lose the value.
  static List<String> _migrateEntries(String host, String project) => [
    r'''ensure_group() {
  local parent
  if kp ls "$file" "$1" >/dev/null 2>&1; then return 0; fi
  parent="${1%/*}"
  if [ "$parent" != "$1" ]; then ensure_group "$parent" || return 1; fi
  kp mkdir "$file" "$1" >/dev/null
}''',
    r'''move_entry() {
  local value copied
  if ! kp show "$file" "$1" >/dev/null 2>&1; then return 0; fi
  if kp show "$file" "$2" >/dev/null 2>&1; then
    echo "Both $1 and $2 exist; neither was changed." >&2
    return 0
  fi
  value="$(kp show -s -a password "$file" "$1" 2>/dev/null)" || {
    echo "Could not read $1; the old entry was kept." >&2; return 1;
  }
  ensure_group "${2%/*}" || return 1
  if ! printf '%s\n%s\n' "$MASTER" "$value" | "$cli" add -p "$file" "$2" >/dev/null 2>&1; then
    echo "Could not copy $1 to $2; the old entry was kept." >&2; return 1
  fi
  copied="$(kp show -s -a password "$file" "$2" 2>/dev/null)" || {
    echo "Could not read back $2; the old entry was kept." >&2; return 1;
  }
  if [ "$value" != "$copied" ]; then
    echo "$2 does not hold the value of $1; the old entry was kept." >&2; return 1
  fi
  kp rm "$file" "$1" >/dev/null
}''',
    'move_entry ${_word('hosts/$project/vault-passphrase')} ${_word(vaultPassphrase(project))}',
    'if kp ls "\$file" ${_word('hosts/$project/keys')} >/dev/null 2>&1; then',
    // keepassxc-cli translates its empty-group marker, so the listing is read in one language.
    '  entries="\$(LC_ALL=C.UTF-8 LANGUAGE= kp ls -q "\$file" ${_word('hosts/$project/keys')})"',
    r'''  printf '%s\n' "$entries" | while IFS= read -r name; do''',
    r'''    if [ -z "$name" ] || [ "$name" = '[empty]' ]; then continue; fi''',
    r'''    if ! [[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then echo "A legacy vault entry has an invalid name; it was kept." >&2; exit 1; fi''',
    '    move_entry ${_word('hosts/$project/keys/')}"\$name" ${_word('projects/$project/keys/')}"\$name"',
    '  done',
    '  unset entries',
    'fi',
    'move_entry ${_word('shared/forge-ca-key')} ${_word(forgeCaKey(host))}',
    'move_entry ${_word('shared/forge-ca')} ${_word(forgeCa(host))}',
  ];

  /// The script that makes the file where [create] says so, gives [host] a WireGuard key and [project] a vault
  /// passphrase where absent, keeps the files of [keys] (vault entry name to file) base64, and writes only the
  /// key's public half to [publicKeyOut], `0600`.
  ///
  /// A key in [migrateKeyFrom], the host's key from before the file, is taken into the file and that file then
  /// removed. Input checks precede migration; a legacy entry is removed only after its copy reads back unchanged.
  String prepareHost({
    required String host,
    required String project,
    required bool create,
    required String publicKeyOut,
    String? migrateKeyFrom,
    Map<String, String> keys = const {},
  }) {
    checkHost(host);
    _checkProject(project);
    checkPath(publicKeyOut);
    if (migrateKeyFrom != null) checkPath(migrateKeyFrom);
    for (final entry in keys.entries) {
      checkKeyName(entry.key);
      checkPath(entry.value);
    }
    final key = _word(hostKey(host));
    final passphrase = _word(vaultPassphrase(project));
    final hostGroup = _word('hosts/$host');
    final projectGroup = _word('projects/$project');
    final drive = migrateKeyFrom == null ? null : _word(migrateKeyFrom);
    final files = keys.entries.toList();
    return [
      ..._shellStart,
      'cli=${_word(cli)}',
      'file=${_word(file)}',
      'out=${_word(publicKeyOut)}',
      _kp,
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
      // A vault entry's file is outside input: a plain file reached through no link, with bytes, read once here.
      for (var i = 0; i < files.length; i++) ...[
        'if [ "\$(/usr/bin/realpath -e -- ${_word(files[i].value)} 2>/dev/null)" != ${_word(files[i].value)} ] || '
            '[ ! -f ${_word(files[i].value)} ] || [ ! -s ${_word(files[i].value)} ]; then '
            'echo "${files[i].value} is not a plain file with content, reached through no link; nothing was changed." >&2; exit 1; fi',
        'k$i="\$(/usr/bin/base64 -w0 < ${_word(files[i].value)})"',
      ],
      // The drive's copy is outside input: a link or a key wg cannot read is refused.
      if (drive != null) ...[
        'if [ -L $drive ]; then echo "The drive\'s wireguard.key is a link; nothing was changed." >&2; exit 1; fi',
        'if [ -e $drive ] && [ ! -f $drive ]; then echo "The drive\'s wireguard.key is not a file; nothing was changed." >&2; exit 1; fi',
        'if [ -f $drive ]; then old="\$(/usr/bin/tr -d \'[:space:]\' < $drive)"; '
            'if ! valid "\$old"; then echo "The drive\'s wireguard.key is no WireGuard key; nothing was changed." >&2; exit 1; fi; '
            'else old=""; fi',
      ] else
        'old=""',
      if (create) ...[
        'private=""',
        for (var i = 0; i < files.length; i++) 'have$i=""',
      ] else ...[
        r'if ! kp ls "$file" >/dev/null 2>&1; then echo "$file did not open with that password; nothing was changed." >&2; exit 1; fi',
        'private="\$(kp show -s -a password "\$file" $key 2>/dev/null || true)"',
        // An entry there that holds no key, or nothing, is the person's to mend: never added over, nor used.
        'if [ -z "\$private" ] && kp show "\$file" $key >/dev/null 2>&1; then '
            'echo "Your secrets file has an empty ${hostKey(host)}; remove it there. Nothing was changed." >&2; exit 1; fi',
        'if [ -n "\$private" ] && ! valid "\$private"; then '
            'echo "Your secrets file keeps no WireGuard key in ${hostKey(host)}; nothing was changed." >&2; exit 1; fi',
        // A copy still on the drive goes only when it is the file's own key; another key for the host stops it all.
        'if [ -n "\$private" ] && [ -n "\$old" ] && [ "\$old" != "\$private" ]; then '
            'echo "The drive holds another key for this server than your secrets file; nothing was changed." >&2; exit 1; fi',
        // One already kept under that name is replaced only by the same bytes.
        for (var i = 0; i < files.length; i++) ...[
          'entry$i=${_word(vaultKey(project, files[i].key))}',
          'if ! kp show "\$file" "\$entry$i" >/dev/null 2>&1 && '
              'kp show "\$file" ${_word('hosts/$project/keys/${files[i].key}')} >/dev/null 2>&1; then '
              'entry$i=${_word('hosts/$project/keys/${files[i].key}')}; fi',
          'have$i="\$(kp show -s -a password "\$file" "\$entry$i" 2>/dev/null || true)"',
          'if [ -z "\$have$i" ] && kp show "\$file" "\$entry$i" >/dev/null 2>&1; then '
              'echo "Your secrets file has an empty \$entry$i; remove it there. Nothing was '
              'changed." >&2; exit 1; fi',
          'if [ -n "\$have$i" ] && [ "\$have$i" != "\$k$i" ]; then echo "Your secrets file keeps another '
              '${files[i].key} for this server; remove it there to take the new one. Nothing was changed." >&2; exit 1; fi',
        ],
      ],
      // Legacy values must move before missing entries can be generated without replacing an existing secret.
      if (!create) ..._migrateEntries(host, project),
      if (create) ...[
        r'/usr/bin/mkdir -p "$(/usr/bin/dirname "$file")"',
        r'printf'
            " '%s\\n%s\\n' "
            r'"$MASTER" "$MASTER" | "$cli" db-create -p "$file" >/dev/null',
        'kp mkdir "\$file" ${_word('shared')} >/dev/null',
        'kp mkdir "\$file" ${_word('hosts')} >/dev/null',
      ] else
        'kp ls "\$file" ${_word('hosts')} >/dev/null 2>&1 || kp mkdir "\$file" ${_word('hosts')} >/dev/null',
      'kp ls "\$file" $hostGroup >/dev/null 2>&1 || kp mkdir "\$file" $hostGroup >/dev/null',
      'kp ls "\$file" ${_word('projects')} >/dev/null 2>&1 || kp mkdir "\$file" ${_word('projects')} >/dev/null',
      'kp ls "\$file" $projectGroup >/dev/null 2>&1 || kp mkdir "\$file" $projectGroup >/dev/null',
      'if [ -n "\$private" ]; then :',
      'elif [ -n "\$old" ]; then private="\$old"; '
          '{ printf \'%s\\n%s\\n\' "\$MASTER" "\$private"; } | "\$cli" add -p "\$file" $key >/dev/null',
      'else private="\$(/usr/bin/wg genkey)"; '
          '{ printf \'%s\\n%s\\n\' "\$MASTER" "\$private"; } | "\$cli" add -p "\$file" $key >/dev/null',
      'fi',
      'kp show "\$file" $passphrase >/dev/null 2>&1 || kp add -g -L 32 "\$file" $passphrase >/dev/null',
      if (keys.isNotEmpty)
        'kp ls "\$file" ${_word('projects/$project/keys')} >/dev/null 2>&1 || '
            'kp mkdir "\$file" ${_word('projects/$project/keys')} >/dev/null',
      for (var i = 0; i < files.length; i++)
        'if [ -z "\$have$i" ]; then { printf \'%s\\n%s\\n\' "\$MASTER" "\$k$i"; } | '
            '"\$cli" add -p "\$file" ${_word(vaultKey(project, files[i].key))} >/dev/null; fi',
      // Read back before anything is removed: the file must hold what is used.
      'if [ "\$(kp show -s -a password "\$file" $key 2>/dev/null)" != "\$private" ] || ! valid "\$private"; then '
          'echo "The secrets file does not hold a WireGuard key for this server; nothing was removed." >&2; exit 1; fi',
      for (var i = 0; i < files.length; i++)
        'if [ "\$(kp show -s -a password "\$file" ${_word(vaultKey(project, files[i].key))} 2>/dev/null)" != "\$k$i" ]; then '
            'echo "The secrets file does not hold ${files[i].key}; nothing was removed." >&2; exit 1; fi',
      if (drive != null) 'if [ -n "\$old" ]; then /usr/bin/rm -f $drive; fi',
      r'''pub="$(printf '%s\n' "$private" | /usr/bin/wg pubkey)"''',
      r'if [ -z "$pub" ]; then echo "wg gave no public key; nothing was written." >&2; exit 1; fi',
      r'''printf '%s\n' "$pub" > "$out.new"''',
      r'/usr/bin/mv "$out.new" "$out"',
      'unset MASTER private pub old${[for (var i = 0; i < files.length; i++) ' k$i have$i entry$i'].join()}',
      r'echo "The secrets file is ready."',
    ].join('\n');
  }
}
