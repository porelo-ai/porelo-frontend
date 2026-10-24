import 'package:porelo_host/porelo_host.dart';

/// Refuses anything except a plain absolute local file path before a root command is opened.
void checkVpnFile(String file) {
  if (!file.startsWith('/') || file.length < 2 || RegExp(r'[^A-Za-z0-9 /._:@%+=,-]').hasMatch(file)) {
    throw const FormatException(
      'The saved VPN file needs a plain absolute path, without quotes, shell characters or line breaks. Save it again in a private folder.',
    );
  }
}

/// Installs one explicitly chosen file, then brings up the tunnel only if installation succeeds.
List<String> hostVpnUpCommand(String file) {
  checkVpnFile(file);
  return [
    '/bin/sh',
    '-c',
    r'sudo install -m 600 "$1" /etc/wireguard/porelo.conf && sudo wg-quick up porelo',
    'porelo-vpn',
    file,
  ];
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
