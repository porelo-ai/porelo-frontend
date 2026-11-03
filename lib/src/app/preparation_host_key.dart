import 'package:porelo_host/porelo_host.dart' show checkedEd25519;

import 'machines.dart' show openSsh;
import 'run_here.dart';

/// The fetched key and the fingerprint ssh-keygen computed from that exact key.
typedef PreparationHostKey = ({String key, String fingerprint});

/// Fetches only Ed25519; this one optional first-use policy can be removed independently of pasted keys.
Future<PreparationHostKey> fetchPreparationHostKey(String address, {int port = 22, RunHere? run}) async {
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9.:-]*$').hasMatch(address) || port < 1 || port > 65535) {
    throw const WorkspaceRefused('Give the server name or IP address before fetching its SSH host key.');
  }
  final execute = run ?? runHere;
  try {
    final scan = await execute(openSsh('ssh-keyscan'), ['-T', '5', '-t', 'ed25519', '-p', '$port', address]);
    final keys = <String>{};
    for (final line in scan.out.split('\n')) {
      if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
      final fields = line.trim().split(RegExp(r'\s+'));
      if (fields.length != 3 || fields[1] != 'ssh-ed25519') throw const FormatException();
      final key = '${fields[1]} ${fields[2]}';
      checkedEd25519(key);
      keys.add(key);
    }
    if (scan.code != 0 || keys.length != 1) throw const FormatException();
    final key = keys.single;
    final printed = await execute(openSsh('ssh-keygen'), ['-lf', '-'], input: '$key\n');
    final lines = printed.out.trim().split('\n');
    final fingerprint = lines.length == 1
        ? RegExp(r'^256 (SHA256:[A-Za-z0-9+/]{43})\s').firstMatch(lines.single)
        : null;
    if (printed.code != 0 || fingerprint == null) throw const FormatException();
    return (key: key, fingerprint: fingerprint.group(1)!);
  } on Exception {
    throw const WorkspaceRefused(
      'The SSH host key could not be fetched and checked. '
      'Paste the server’s checked public key below, or fetch it again.',
    );
  }
}
