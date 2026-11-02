import 'package:porelo_frontend/src/app/settings.dart';

/// Public setup data for an SSH-only server.
const signedSetup = HostUpRecord(
  scalewayProject: 'provider',
  host: 'orchard',
  hostName: 'orchard',
  publicKey: '/keys/person.pub',
);
