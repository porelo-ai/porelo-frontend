import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_host/porelo_host.dart';

import 'host_admin.dart';

/// A public test CA made with OpenSSL; its private key was discarded.
const hostMatrixCa = '''-----BEGIN CERTIFICATE-----
MIIBkTCCATegAwIBAgIUKqcZKFcHG2Sz5NG59GqETNC8dNswCgYIKoZIzj0EAwIw
HjEcMBoGA1UEAwwTaG9zdC1jYS5leGFtcGxlLm9yZzAeFw0yNjEwMjkyMDM5MDha
Fw0zNjEwMjYyMDM5MDhaMB4xHDAaBgNVBAMME2hvc3QtY2EuZXhhbXBsZS5vcmcw
WTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAASO7lv86RaLx1+tCWpDmDCjjm6Br435
8pPVFeGqaiixwbJy1oOZYQoLoE6KLKEqx7A+AzDGHxxKXTO0pXwC4Po4o1MwUTAd
BgNVHQ4EFgQUFmnyQVrxprqwsE7U0Kk0qTT2ykwwHwYDVR0jBBgwFoAUFmnyQVrx
prqwsE7U0Kk0qTT2ykwwDwYDVR0TAQH/BAUwAwEB/zAKBggqhkjOPQQDAgNIADBF
AiEAjhpuuMtWaRjZJezh0ksJbuM6mC+2baN/ptXIfimGYUUCIE5OpOh1azfaU01R
Ml+ru1u3FTg7Kq7empTVHKa5LHmr
-----END CERTIFICATE-----
''';

/// The SHA-256 of the certificate's DER, measured independently with sha256sum.
const hostMatrixCaSha256 = '5ffb84726cb1d63b50878c476184af9e3b8abd90cf26d93b2eb73a08b66da0a2';

/// The host's public values with the digest of its actual test CA.
Map<String, Object?> matrixHostValues({String host = 'orchard'}) => {
  ...hostValues(),
  'ca_sha256': hostMatrixCaSha256,
  'homeserver': 'matrix.$host.porelo.internal',
};

/// A retained host record holding only this host's public CA.
HostUpRecord matrixHostRecord({String host = 'orchard'}) => HostUpRecord(
  host: host,
  hostName: host,
  vpnNetworkNumber: 7,
  vpnInterface: 'porelo-7',
  preparedHost: PreparedHost.read(matrixHostValues(host: host)),
  scalewayProject: 'fixture',
  account: 'root',
  tresor: '',
  folder: null,
  signingKey: '',
  identity: '/keys/$host',
  publicKey: '/keys/$host.pub',
  collection: '',
  vpnPeerPublicKey: '',
  vpnPeerAddress: '',
  forgeCa: hostMatrixCa,
);
