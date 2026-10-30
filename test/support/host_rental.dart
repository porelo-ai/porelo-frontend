import 'package:porelo_frontend/src/app/settings.dart';

/// A saved project-mode rental from before signed-state joining.
Map<String, Object?> legacyRental() => {
  'scalewayProject': 'provider',
  'account': 'worker',
  'tresor': '',
  'folder': null,
  'identity': '/keys/old-private',
  'publicKey': '/keys/old-public',
  'signingKey': '',
  'collection': '',
  'vpnPeerPublicKey': '',
  'vpnPeerAddress': '',
  'preparing': true,
  'startedAt': DateTime.utc(2000).toIso8601String(),
};

/// Public setup data for an SSH-only server.
const signedSetup = HostUpRecord(
  scalewayProject: 'provider',
  host: 'orchard',
  hostName: 'orchard',
  publicKey: '/keys/person.pub',
);
