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
  static String? missingCli([String cli = keepassxcCli]) => File(cli).existsSync()
      ? null
      : 'KeePassXC\'s command line is not installed here ($cli), so the secrets file cannot be opened. Install it, '
            'in a terminal of your own: $installCli';

  /// What installs [keepassxcCli], to be run by the person in a terminal of their own.
  static const installCli = 'sudo apt install keepassxc-minimal';

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
  static const stopNeeds = <String>{
    'vault',
    'vault-new',
    'wireguard',
    'keys',
    'forge-central-token',
    'forge-certificate',
  };

  /// The entries of the person's lasting CA, which signs every host's forge certificate: its key and its certificate,
  /// each PEM kept base64, made once.
  static const forgeCaKey = 'shared/forge-ca-key';

  /// The lasting CA's certificate, PEM kept base64.
  static const forgeCa = 'shared/forge-ca';

  /// The forge's address and name on the VPN, which every host's forge certificate names, set here and never taken
  /// from the host's request.
  static const forgeAddress = '10.73.0.1';

  /// The forge's name, which the VPN step resolves to [forgeAddress] on this desktop.
  static const forgeName = 'forge.porelo.internal';

  // The host's request is in `$request`, fetched by the stop's terminal before the pipe; it is public. The CA's key
  // passes from keepassxc-cli to openssl on pipes only. Every extension and the subject are set here; nothing of the
  // request counts but its key.
  static final _forgeCertificate = <String>[
    r'''cakey64="$(kp show -s -a password "$file" 'shared/forge-ca-key' 2>/dev/null || true)"''',
    r'''ca64="$(kp show -s -a password "$file" 'shared/forge-ca' 2>/dev/null || true)"''',
    r'''if { [ -z "$cakey64" ] && [ -n "$ca64" ]; } || { [ -n "$cakey64" ] && [ -z "$ca64" ]; }; then echo "$file keeps only one of shared/forge-ca-key and shared/forge-ca; nothing was sent." >&2; exit 1; fi''',
    // Made once, in this terminal, the first time a host asks: ten years, held to the VPN's names and addresses.
    r'''if [ -z "$cakey64" ]; then''',
    r'''  cakey="$(/usr/bin/openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 2>/dev/null)"''',
    r'''  ca="$(/usr/bin/openssl req -x509 -new -key <(printf '%s\n' "$cakey") -subj '/CN=Porelo forge CA' -days 3650 -addext 'basicConstraints=critical,CA:TRUE,pathlen:0' -addext 'keyUsage=critical,keyCertSign,cRLSign' -addext 'nameConstraints=critical,permitted;DNS:porelo.internal,permitted;IP:10.73.0.0/255.255.255.0')"''',
    r'''  kp ls "$file" 'shared' >/dev/null 2>&1 || kp mkdir "$file" 'shared' >/dev/null''',
    r'''  { printf '%s\n%s\n' "$MASTER" "$(printf '%s\n' "$cakey" | /usr/bin/base64 -w0)"; } | "$cli" add -p "$file" 'shared/forge-ca-key' >/dev/null''',
    r'''  { printf '%s\n%s\n' "$MASTER" "$(printf '%s\n' "$ca" | /usr/bin/base64 -w0)"; } | "$cli" add -p "$file" 'shared/forge-ca' >/dev/null''',
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

  /// The entry of a vault entry's file for [project]'s host, its bytes base64 in the password field.
  static String vaultKey(String project, String name) => 'hosts/$project/keys/$name';

  /// The script that writes the stop's lines for [needs], one `<need> <base64>` per secret and `key <name> <base64>`
  /// per name in [keys], to standard output, which is the pipe to the host's `porelo-host-stop --stdin`.
  ///
  /// [keys] are the vault entries `machine.yml` names, none or more; another entry the file keeps for the host is
  /// never sent. Every entry is read and encoded before the first line is written, so a missing one sends nothing
  /// and is named.
  String stopLines({required String project, required List<String> needs, List<String> keys = const []}) {
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
        'wireguard' => hostKey(project),
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
        reads.addAll(_forgeCertificate);
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
      ..._shellStart,
      'cli=${_word(cli)}',
      'file=${_word(file)}',
      // Whole groups of four, padded at the end only: what the host decodes as it stands.
      r"b64='^([A-Za-z0-9+/]{4})*([A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$'",
      _kp,
      r'''get() { local value; value="$(kp show -s -a password "$file" "$1" 2>/dev/null || true)"; if [ -z "$value" ]; then echo "$file has no entry $1; nothing was sent." >&2; return 1; fi; printf '%s' "$value"; }''',
      r'IFS= read -rs -p "The master password of $file: " MASTER; echo >&2',
      r'if [ -z "$MASTER" ]; then echo "A master password cannot be empty; nothing was sent." >&2; exit 1; fi',
      r'if ! kp ls "$file" >/dev/null 2>&1; then echo "$file did not open with that password; nothing was sent." >&2; exit 1; fi',
      ...reads,
      ...writes,
      'unset MASTER ${variables.join(' ')}',
    ].join('\n');
  }

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

  /// The script that makes the file where [create] says so, gives [project]'s host a WireGuard key and a vault
  /// passphrase where it has none, keeps the files of [keys] (vault entry name to file) base64, and writes only the
  /// key's public half to [publicKeyOut], `0600`.
  ///
  /// A key in [migrateKeyFrom], the host's key from before the file, is taken into the file and that file then
  /// removed. Everything is checked before the first change: a run that refuses changes nothing.
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
      checkKeyName(entry.key);
      checkPath(entry.value);
    }
    final key = _word(hostKey(project));
    final passphrase = _word(vaultPassphrase(project));
    final group = _word('hosts/$project');
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
            'echo "Your secrets file has an empty ${hostKey(project)}; remove it there. Nothing was changed." >&2; exit 1; fi',
        'if [ -n "\$private" ] && ! valid "\$private"; then '
            'echo "Your secrets file keeps no WireGuard key in ${hostKey(project)}; nothing was changed." >&2; exit 1; fi',
        // A copy still on the drive goes only when it is the file's own key; another key for the host stops it all.
        'if [ -n "\$private" ] && [ -n "\$old" ] && [ "\$old" != "\$private" ]; then '
            'echo "The drive holds another key for this server than your secrets file; nothing was changed." >&2; exit 1; fi',
        // One already kept under that name is replaced only by the same bytes.
        for (var i = 0; i < files.length; i++) ...[
          'have$i="\$(kp show -s -a password "\$file" ${_word(vaultKey(project, files[i].key))} 2>/dev/null || true)"',
          'if [ -z "\$have$i" ] && kp show "\$file" ${_word(vaultKey(project, files[i].key))} >/dev/null 2>&1; then '
              'echo "Your secrets file has an empty ${vaultKey(project, files[i].key)}; remove it there. Nothing was '
              'changed." >&2; exit 1; fi',
          'if [ -n "\$have$i" ] && [ "\$have$i" != "\$k$i" ]; then echo "Your secrets file keeps another '
              '${files[i].key} for this server; remove it there to take the new one. Nothing was changed." >&2; exit 1; fi',
        ],
      ],
      // Every check is behind; from here on the file changes.
      if (create) ...[
        r'/usr/bin/mkdir -p "$(/usr/bin/dirname "$file")"',
        r'printf'
            " '%s\\n%s\\n' "
            r'"$MASTER" "$MASTER" | "$cli" db-create -p "$file" >/dev/null',
        'kp mkdir "\$file" ${_word('shared')} >/dev/null',
        'kp mkdir "\$file" ${_word('hosts')} >/dev/null',
      ] else
        'kp ls "\$file" ${_word('hosts')} >/dev/null 2>&1 || kp mkdir "\$file" ${_word('hosts')} >/dev/null',
      'kp ls "\$file" $group >/dev/null 2>&1 || kp mkdir "\$file" $group >/dev/null',
      'if [ -n "\$private" ]; then :',
      'elif [ -n "\$old" ]; then private="\$old"; '
          '{ printf \'%s\\n%s\\n\' "\$MASTER" "\$private"; } | "\$cli" add -p "\$file" $key >/dev/null',
      'else private="\$(/usr/bin/wg genkey)"; '
          '{ printf \'%s\\n%s\\n\' "\$MASTER" "\$private"; } | "\$cli" add -p "\$file" $key >/dev/null',
      'fi',
      'kp show "\$file" $passphrase >/dev/null 2>&1 || kp add -g -L 32 "\$file" $passphrase >/dev/null',
      if (keys.isNotEmpty)
        'kp ls "\$file" ${_word('hosts/$project/keys')} >/dev/null 2>&1 || '
            'kp mkdir "\$file" ${_word('hosts/$project/keys')} >/dev/null',
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
      'unset MASTER private pub old${[for (var i = 0; i < files.length; i++) ' k$i have$i'].join()}',
      r'echo "The secrets file is ready."',
    ].join('\n');
  }
}
