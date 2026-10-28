import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ffi';

import 'package:path/path.dart' as path;
import 'package:porelo_host/porelo_host.dart';

/// Refuses anything except a plain absolute local file path before a root command is opened.
void checkVpnFile(String file) {
  if (!file.startsWith('/') || file.length < 2 || RegExp(r'[^A-Za-z0-9 /._:@%+=,-]').hasMatch(file)) {
    throw const FormatException(
      'The saved VPN file needs a plain absolute path, without quotes, shell characters or line breaks. Save it again in a private folder.',
    );
  }
}

/// Refuses a file to save the VPN connection to; on Windows no root command ever reads it.
void checkVpnSaveFile(String file, {bool? windows}) {
  if (!(windows ?? Platform.isWindows)) return checkVpnFile(file);
  if (!path.windows.isAbsolute(file) ||
      !RegExp(r'^([A-Za-z]:[\\/]|\\\\)').hasMatch(file) ||
      RegExp(r'[\x00-\x1f"<>|*?]').hasMatch(file)) {
    throw const FormatException(
      'The saved VPN file needs a plain absolute path, without quotes or line breaks. Save it again in a private folder.',
    );
  }
}

/// Checks the active endpoint before installation and confirms a fresh handshake after a ping.
List<String> hostVpnUpCommand(String file, {String commandPath = '/usr/bin:/usr/sbin:/bin:/sbin', String? forgeCa}) {
  checkVpnFile(file);
  if (forgeCa != null && !isForgeCaCertificate(forgeCa)) {
    throw const FormatException('The CA for the server\'s forge is not one certificate.');
  }
  final lines = File(file).readAsLinesSync();
  String field(String name) => lines.where((line) => line.startsWith('$name = ')).single.substring(name.length + 3);
  final key = field('PublicKey');
  final endpoint = field('Endpoint');
  return [
    'sudo',
    '/bin/sh',
    '-c',
    _vpnRootStep,
    'porelo-vpn',
    file,
    '$file.checked',
    key,
    endpoint,
    commandPath,
    // Without its last line break, which the root step writes back.
    forgeCa?.trimRight() ?? '',
  ];
}

const _vpnRootStep = r'''
set -u
fail() { printf '%s\n' "$1"; exit 1; }
source=$1
receipt=$2
expected=$3
endpoint=$4
PATH=$5
export PATH
started=$(date -u +%s) || fail 'The VPN check could not read its start time.'
interfaces=$(wg show interfaces) || fail 'The active VPN interfaces could not be checked.'
up=no
for interface in $interfaces; do
  if [ "$interface" = porelo ]; then
    peers=$(wg show porelo endpoints) || fail 'The active VPN endpoint could not be checked.'
    wanted=$(printf '%s\t%s' "$expected" "$endpoint")
    [ "$peers" = "$wanted" ] || fail 'A VPN to another server is already up. Take it down before connecting to this server.'
    up=yes
  fi
done
# WireGuard records whole seconds; the first handshake must be later than the start.
sleep 1 || fail 'The VPN handshake check could not start.'
# NetworkManager must leave this link alone before WireGuard replaces it.
nm_directory=/etc/NetworkManager/conf.d
nm_rule='[keyfile]
unmanaged-devices=interface-name:porelo'
if [ -d "$nm_directory" ] && ! printf '%s\n' "$nm_rule" | cmp -s "$nm_directory/porelo.conf" -; then
  nm_temporary=$(mktemp "$nm_directory/.porelo.conf.XXXXXX") || fail 'The NetworkManager configuration could not be staged.'
  trap 'rm -f -- "$nm_temporary"' 0
  trap 'exit 1' HUP INT TERM
  printf '%s\n' "$nm_rule" > "$nm_temporary" || fail 'The NetworkManager configuration could not be written.'
  chmod 0644 "$nm_temporary" || fail 'The NetworkManager configuration could not be protected.'
  mv -f -- "$nm_temporary" "$nm_directory/porelo.conf" || fail 'The NetworkManager configuration could not be installed.'
  trap - 0 HUP INT TERM
  if nmcli=$(command -v nmcli); then
    "$nmcli" general reload conf >/dev/null 2>&1 || true
  fi
fi
# A running tunnel does not handshake again within its rekey window and keeps its old configuration.
if [ "$up" = yes ]; then
  wg-quick down porelo >/dev/null 2>&1 || fail 'The VPN to this server could not be taken down to renew it.'
fi
install -m 600 -- "$source" /etc/wireguard/porelo.conf >/dev/null 2>&1 || fail 'The VPN configuration could not be installed.'
wg-quick up porelo >/dev/null 2>&1 || fail 'The VPN could not be brought up.'
ping -c 3 -W 2 10.73.0.1 >/dev/null 2>&1 || fail 'The server did not answer through the VPN.'
handshakes=$(wg show porelo latest-handshakes) || fail 'The VPN handshake could not be read.'
handshake=$(printf '%s\n' "$handshakes" | awk -v key="$expected" '$1 == key { print $2 }')
case "$handshake" in ''|*[!0-9]*) fail 'The server did not complete the expected VPN handshake.';; esac
[ "$handshake" -gt "$started" ] || fail 'The server did not complete a new VPN handshake.'
# The person's lasting CA for the hosts' forges, and the forge's name, where a stop gave the CA: in the system store,
# in Firefox's policy and in /etc/hosts, each only where it is not there already. The CA comes as an argument, public:
# root reads no file of the person's, and checks it is a certificate in a file of its own before any copy is made.
forge_ca_pem=${6:-}
if [ -n "$forge_ca_pem" ]; then
  forge_ca=$(mktemp) || fail "The CA for the server's forge could not be staged."
  trap 'rm -f -- "$forge_ca"' 0
  trap 'exit 1' HUP INT TERM
  printf '%s\n' "$forge_ca_pem" > "$forge_ca" || fail "The CA for the server's forge could not be staged."
  [ "$(head -n 1 "$forge_ca")" = '-----BEGIN CERTIFICATE-----' ] && [ "$(tail -n 1 "$forge_ca")" = '-----END CERTIFICATE-----' ] \
    && [ "$(grep -c -- '-----' "$forge_ca")" = 2 ] && ! grep -vqE -- '^(-----(BEGIN|END) CERTIFICATE-----|[A-Za-z0-9+/=]+)$' "$forge_ca" \
    || fail "What was given as the CA for the server's forge is not one certificate."
  if command -v update-ca-certificates >/dev/null 2>&1; then
    store=/usr/local/share/ca-certificates/porelo-host.crt
    store_update=update-ca-certificates
  elif command -v update-ca-trust >/dev/null 2>&1; then
    store=/etc/pki/ca-trust/source/anchors/porelo-host.crt
    store_update=update-ca-trust
  else
    store=
  fi
  if [ -z "$store" ]; then
    printf '%s\n' "This computer has no tool for a system store of certificates; only Firefox trusts the forge."
  elif ! cmp -s -- "$forge_ca" "$store"; then
    install -D -m 0644 -- "$forge_ca" "$store" || fail "The CA for the server's forge could not be put into the system store."
    # Taken back where the store did not take it, so the next start tries again.
    "$store_update" >/dev/null 2>&1 || { rm -f -- "$store"; fail "The system store did not take the CA for the server's forge."; }
  fi
  # Firefox, a snap here, reads /etc/firefox alone; its policy names this copy.
  firefox_ca=/etc/firefox/porelo/porelo-host.crt
  cmp -s -- "$forge_ca" "$firefox_ca" || install -D -m 0644 -- "$forge_ca" "$firefox_ca" || fail "The CA for the server's forge could not be put where Firefox reads it."
  policy=/etc/firefox/policies/policies.json
  # A link in its place, dangling or not, is the person's: said, never replaced.
  if [ ! -e "$policy" ] && [ ! -L "$policy" ]; then
    install -d -m 0755 /etc/firefox/policies || fail "Firefox's policy folder could not be made."
    staged=$(mktemp /etc/firefox/policies/.policies.json.XXXXXX) || fail "Firefox's policy could not be staged."
    printf '%s\n' '{"policies":{"Certificates":{"Install":["/etc/firefox/porelo/porelo-host.crt"]}}}' > "$staged" \
      && chmod 0644 "$staged" && mv -f -- "$staged" "$policy" || { rm -f -- "$staged"; fail "Firefox's policy could not be written."; }
    printf '%s\n' 'Firefox trusts the forge once it is started again.'
  elif ! grep -q '/etc/firefox/porelo/porelo-host.crt' "$policy"; then
    printf '%s\n' "Firefox has a policy of its own in $policy: add /etc/firefox/porelo/porelo-host.crt to its Certificates.Install to open the forge there."
  fi
  hosts_line='10.73.0.1 forge.porelo.internal # porelo-host'
  if ! grep -qxF -- "$hosts_line" /etc/hosts; then
    # On a line of its own, and into the file as it is, so its owner, mode and label stay.
    if [ -n "$(tail -c 1 /etc/hosts)" ]; then printf '\n' >> /etc/hosts; fi
    printf '%s\n' "$hosts_line" >> /etc/hosts || fail "The forge's name could not be written to /etc/hosts."
  fi
  rm -f -- "$forge_ca"
  trap - 0 HUP INT TERM
fi
printf '%s\t%s\t%s\n' "$expected" "$started" "$handshake" > "$receipt" || fail 'The VPN check could not be kept.'
printf '%s\n' 'The VPN is up and the server answers. You can close this window.'
''';

/// One certificate in PEM and nothing beside it: base64 lines between its two markers, which decode.
bool isForgeCaCertificate(String pem) {
  final match = RegExp(r'^-----BEGIN CERTIFICATE-----\n((?:[A-Za-z0-9+/]{1,76}={0,2}\n)+)-----END CERTIFICATE-----\n?$')
      .firstMatch(pem);
  if (match == null) return false;
  try {
    return base64.decode(match.group(1)!.replaceAll('\n', '')).isNotEmpty;
  } on FormatException {
    return false;
  }
}

/// Takes the VPN down, and the forge's name with it from `/etc/hosts`, which only this link reaches: that one line,
/// written into the file as it is, so its owner, mode and label stay.
const hostVpnDownCommand = <String>[
  '/usr/bin/sudo',
  '/bin/sh',
  '-c',
  r'''PATH=/usr/bin:/usr/sbin:/bin:/sbin
wg-quick down porelo || exit
line='10.73.0.1 forge.porelo.internal # porelo-host'
grep -qxF -- "$line" /etc/hosts || exit 0
kept=$(mktemp) || exit
trap 'rm -f -- "$kept"' 0
grep -vxF -- "$line" /etc/hosts > "$kept"
cat -- "$kept" > /etc/hosts''',
  'porelo-vpn-down',
];

/// A private configuration whose lifetime is the local terminal, including cancellation.
class HostVpnAttempt {
  HostVpnAttempt._(this.directory, this.file, this.publicKey, this.started, {this.forgeCa});

  /// The lasting CA's certificate for the hosts' forges, PEM, public; null where none is kept. The root step gets it
  /// as an argument and reads no file of this user's for it.
  final String? forgeCa;

  /// The exclusively created private directory in this account's runtime directory.
  final Directory directory;

  /// The configuration, never a saved export from another device.
  final File file;

  /// The expected server's public half.
  final String publicKey;

  /// The earliest acceptable root step start, in seconds since the epoch.
  final int started;

  /// Builds the privileged command with public values only.
  List<String> get command => hostVpnUpCommand(file.path, forgeCa: forgeCa)..[0] = '/usr/bin/sudo';

  /// A process exit alone cannot confirm the expected peer's fresh handshake.
  Future<bool> verified() async {
    final receipt = File('${file.path}.checked');
    if (!await receipt.exists()) return false;
    final fields = (await receipt.readAsString()).trim().split('\t');
    if (fields.length != 3 || fields.first != publicKey) return false;
    final start = int.tryParse(fields[1]);
    final handshake = int.tryParse(fields[2]);
    return start != null && handshake != null && start >= started && handshake > start;
  }

  /// Deletes the key and receipt once, whether the terminal succeeded or failed.
  Future<void> close() => _closing ??= _remove();

  Future<void>? _closing;

  Future<void> _remove() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}

/// Refuses an unsafe runtime directory before reading a private key from its store.
Future<HostVpnAttempt> prepareHostVpn({
  required String project,
  required HostTunnel tunnel,
  required String address,
  SecretStore? secretStore,
  HostFiles Function(SecretStore)? hostFiles,
  Map<String, String>? environment,
  DateTime Function()? now,
  Future<void> Function()? checkRootTools,
  String? forgeCa,
}) async {
  final runtime = (environment ?? Platform.environment)['XDG_RUNTIME_DIR'];
  const refused = HostFilesRefused('The VPN needs XDG_RUNTIME_DIR owned by this user with permissions 0700.');
  if (!Platform.isLinux ||
      runtime == null ||
      !path.isAbsolute(runtime) ||
      await FileSystemEntity.type(runtime, followLinks: false) != FileSystemEntityType.directory) {
    throw refused;
  }
  final identity = DynamicLibrary.process().lookupFunction<Uint32 Function(), int Function()>('geteuid')();
  final stat = await Process.run('/usr/bin/stat', ['-c', '%u %a', '--', runtime]);
  if (stat.exitCode != 0 || '${stat.stdout}'.trim() != '$identity 700') throw refused;
  await (checkRootTools ?? checkHostVpnRootTools)();
  final scratch = await HostFileWriter().createPrivateTemporary(Directory(runtime));
  final file = File(path.join(scratch.path, 'porelo.conf'));
  final attempt = HostVpnAttempt._(
    scratch,
    file,
    tunnel.hostPublicKey,
    (now ?? DateTime.now)().millisecondsSinceEpoch ~/ 1000,
    forgeCa: forgeCa,
  );
  try {
    await withHostFiles(
      (files) => files.exportTunnel(project: project, tunnel: tunnel, address: address, destination: file),
      secretStore: secretStore,
      hostFiles: hostFiles,
    );
    // The root step writes through this existing user-owned receipt without changing its owner.
    await HostFileWriter().write(File('${file.path}.checked'), const []);
    return attempt;
  } catch (_) {
    await attempt.close();
    rethrow;
  }
}

/// Refuses unless every tool the root step runs is root-owned and unwritable by others.
///
/// Each tool is the first found in [directories], the order of the root step's own PATH.
Future<void> checkHostVpnRootTools({
  List<String> directories = const ['/usr/bin', '/usr/sbin', '/bin', '/sbin'],
}) async {
  const refused = HostFilesRefused(
    'The VPN needs root-owned sudo, sh, WireGuard, ping, install, date, sleep, awk, cmp, mktemp, chmod, mv, rm, grep, head, tail, and optional nmcli in protected system directories.',
  );
  try {
    await _checkRootTools(directories, refused);
  } on FileSystemException {
    throw refused;
  }
}

Future<void> _checkRootTools(List<String> directories, HostFilesRefused refused) async {
  final paths = <String>{};
  void includePath(String value) {
    while (true) {
      paths.add(value);
      final parent = path.dirname(value);
      if (parent == value) return;
      value = parent;
    }
  }

  Future<File?> lookUp(String name) async {
    for (final directory in directories) {
      final binary = File(path.join(directory, name));
      if (await FileSystemEntity.type(binary.path) != FileSystemEntityType.notFound) return binary;
    }
    return null;
  }

  for (final directory in directories) {
    includePath(await Directory(directory).resolveSymbolicLinks());
  }
  for (final name in [
    'sudo',
    'sh',
    'wg',
    'wg-quick',
    'ping',
    'install',
    'date',
    'sleep',
    'awk',
    'cmp',
    'mktemp',
    'chmod',
    'mv',
    'rm',
    'grep',
    'head',
    'tail',
    'nmcli',
  ]) {
    final binary = await lookUp(name);
    if (binary == null) {
      if (name == 'nmcli') continue;
      throw refused;
    }
    final resolved = await binary.resolveSymbolicLinks();
    if (await FileSystemEntity.type(resolved) != FileSystemEntityType.file ||
        ((await binary.stat()).mode & 0x40) == 0) {
      throw refused;
    }
    includePath(resolved);
  }
  final stat = await Process.run('/usr/bin/stat', ['-c', '%u %a', '--', ...paths]);
  final rows = '${stat.stdout}'.trim().split('\n');
  if (stat.exitCode != 0 ||
      rows.length != paths.length ||
      rows.any((row) {
        final parts = row.split(' ');
        final mode = parts.length == 2 ? int.tryParse(parts[1], radix: 8) : null;
        return parts.first != '0' || mode == null || (mode & 0x12) != 0;
      })) {
    throw refused;
  }
}

/// Checks local link presence without opening a privileged terminal.
Future<bool> probeHostVpnLink({Future<Process> Function(String, List<String>)? start}) async {
  const refused = HostFilesRefused(
    'The local VPN interface could not be checked. Check that ip is installed and try again.',
  );
  try {
    final process = await (start ?? Process.start)('ip', ['link', 'show', 'dev', 'porelo']);
    final drained = Future.wait([process.stdout.drain<void>(), process.stderr.drain<void>()]);
    try {
      final code = await process.exitCode.timeout(const Duration(seconds: 4));
      if (code != 0 && code != 1) throw refused;
      return code == 0;
    } on TimeoutException {
      process.kill();
      await process.exitCode;
      throw refused;
    } finally {
      await drained;
    }
  } on ProcessException {
    throw refused;
  }
}

/// Probes the VPN without root, bounded even when the peer is gone.
Future<bool> pingHostVpn() async {
  try {
    final process = await Process.start('ping', ['-c', '1', '-W', '2', '-w', '3', '10.73.0.1']);
    final drained = Future.wait([process.stdout.drain<void>(), process.stderr.drain<void>()]);
    try {
      return await process.exitCode.timeout(const Duration(seconds: 4)) == 0;
    } on TimeoutException {
      process.kill();
      await process.exitCode;
      return false;
    } finally {
      await drained;
    }
  } on ProcessException {
    return false;
  }
}

/// Opens the key store only for the requested file work and closes only a store opened here.
Future<void> withHostFiles(
  Future<void> Function(HostFiles) use, {
  SecretStore? secretStore,
  HostFiles Function(SecretStore)? hostFiles,
}) async {
  late final SecretStore store;
  try {
    store = secretStore ?? SecretStore.forThisSystem();
  } on Exception {
    throw const SecretStoreFailed('The system secret store could not be opened.');
  }
  try {
    await use(hostFiles?.call(store) ?? HostFiles(store));
  } finally {
    if (secretStore == null) {
      try {
        await store.close();
      } on Exception {
        throw const SecretStoreFailed('The system secret store could not be closed.');
      }
    }
  }
}
