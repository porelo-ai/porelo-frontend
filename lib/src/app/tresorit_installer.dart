import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Tresorit's Linux installer, split on this desktop for the check the machine makes before any byte of it runs.
///
/// Tresorit publishes no digest for it. The file carries its own signature instead: line 2 is `SIGNATURE=<hex>`,
/// RSASSA-PSS with SHA-512 over everything from line 3 on, and line 3 is `CERT_CHAIN="<certificates>"`, the signing
/// certificate first. This reads that much and finds, in the chain, the CA with the pinned fingerprint; the
/// machine's own `openssl` then checks the rest ([checkScript]), as the user the client is for.
class TresoritInstaller {
  TresoritInstaller._(this.bytes, this.signature, this.signing, this.ca);

  /// Where Tresorit serves it, and replaces it without notice.
  static const url = 'https://installerstorage.blob.core.windows.net/public/install/tresorit_installer.run';

  /// The SHA-256 of "Tresorit Code Signing CA 2020", read from the installer as Tresorit's site serves it, twice and
  /// by separate ways; valid until 2029-12-31.
  static const caSha256 = 'ac4631bcc981ca10063514fb42fd474a9c94bb8e50389c4df42ee201093dd242';

  /// The installer as downloaded, which is what runs once it passed.
  final Uint8List bytes;

  /// Line 2's signature, as bytes.
  final Uint8List signature;

  /// The certificate whose key signed it, PEM.
  final String signing;

  /// The chain's certificate with the pinned fingerprint, PEM: the one the signing certificate is checked against,
  /// and no other.
  final String ca;

  /// Splits [bytes] and finds the pinned CA; refuses, naming why, a file that is not laid out as Tresorit's or whose
  /// chain holds no CA with the pin.
  factory TresoritInstaller.read(Uint8List bytes, {String pinned = caSha256}) {
    final first = bytes.indexOf(10) + 1;
    final second = first == 0 ? -1 : bytes.indexOf(10, first) + 1;
    final third = second <= 0 ? -1 : bytes.indexOf(10, second) + 1;
    if (third <= 0) throw const FormatException('This is no installer Tresorit signed: it has fewer than three lines.');
    // The signature covers only line 3 on, and the file runs from line 1: line 1 may only be the shell's own comment,
    // and line 2 only the signature's assignment, so nothing outside the signature can run.
    if (!headers.contains(latin1.decode(bytes.sublist(0, first - 1)))) {
      throw const FormatException(
        'Line 1 is not #!/bin/sh, so the installer would run what its signature does not cover.',
      );
    }
    final signatureLine = latin1.decode(bytes.sublist(first, second - 1));
    final chainLine = latin1.decode(bytes.sublist(second, third - 1));
    final hex = RegExp(r'^SIGNATURE=([0-9a-fA-F]+)$').firstMatch(signatureLine)?.group(1);
    if (hex == null || hex.length.isOdd) {
      throw const FormatException('Line 2 is not SIGNATURE=<hex>, so this is no installer Tresorit signed.');
    }
    final chain = RegExp(r'^CERT_CHAIN="(.*)"$').firstMatch(chainLine)?.group(1);
    if (chain == null) {
      throw const FormatException(
        'Line 3 is not CERT_CHAIN="<certificates>", so this is no installer Tresorit signed.',
      );
    }
    final certificates = _certificates(chain.replaceAll(r'\n', '\n'));
    if (certificates.length < 2) {
      throw const FormatException(
        'Line 3 holds no signing certificate and CA, so this is no installer Tresorit signed.',
      );
    }
    final pin = pinned.replaceAll(':', '').toLowerCase();
    final ca = certificates.skip(1).where((each) => _sha256(each) == pin).firstOrNull;
    if (ca == null) throw FormatException('The installer\'s chain holds no CA with the pinned fingerprint $pin.');
    return TresoritInstaller._(
      bytes,
      Uint8List.fromList([for (var i = 0; i < hex.length; i += 2) int.parse(hex.substring(i, i + 2), radix: 16)]),
      certificates.first,
      ca,
    );
  }

  /// The first lines an installer may have: a comment to `/bin/sh`, which runs it.
  static const headers = {'#!/bin/sh', '#!/bin/bash'};

  static final _block = RegExp(r'-----BEGIN CERTIFICATE-----\s*([A-Za-z0-9+/=\s]+?)\s*-----END CERTIFICATE-----');

  static List<String> _certificates(String chain) => [
    for (final match in _block.allMatches(chain))
      '-----BEGIN CERTIFICATE-----\n${match.group(1)!.replaceAll(RegExp(r'\s'), '')}\n-----END CERTIFICATE-----\n',
  ];

  static String _sha256(String pem) {
    final body = pem.split('\n').where((line) => !line.startsWith('-----')).join();
    return sha256.convert(base64.decode(body)).toString();
  }

  static String _quoted(String word) => "'${word.replaceAll("'", r"'\''")}'";

  /// The script the user's account runs in [folder], where `installer.run`, `signature.bin`, `signing.pem` and
  /// `ca.pem` were put: `openssl` checks that the pinned CA issued the signing certificate, both valid now, that it is
  /// made for code signing, and that its signature covers the installer from line 3 on as it is; only then does the
  /// installer run, into [clientDir]. Every tool by its path; the folder goes on every ending.
  static String checkScript(String folder, {String clientDir = r'$HOME/.local/share/tresorit'}) => [
    'set -eu',
    'd=${_quoted(folder)}',
    r"""trap '/usr/bin/rm -rf -- "$d"' EXIT""",
    r'cd -- "$d"',
    // Against the pinned CA alone: nothing of the system's own trust store counts.
    '/usr/bin/openssl verify -no-CApath -no-CAstore -partial_chain -CAfile ca.pem signing.pem',
    r"/usr/bin/openssl x509 -in signing.pem -noout -ext extendedKeyUsage | /usr/bin/grep -q 'Code Signing'",
    '/usr/bin/openssl x509 -in signing.pem -noout -pubkey > signing.pub',
    // What the signature does not cover may only be the shell's comment and the signature's own assignment.
    r'''case "$(/usr/bin/head -n 1 installer.run)" in '#!/bin/sh'|'#!/bin/bash') ;; *) echo 'Line 1 is not #!/bin/sh.' >&2; exit 1;; esac''',
    r'''/usr/bin/sed -n 2p installer.run | /usr/bin/grep -Eqx 'SIGNATURE=[0-9a-fA-F]+' || { echo 'Line 2 is not SIGNATURE=<hex>.' >&2; exit 1; }''',
    '/usr/bin/tail -n +3 installer.run > signed.bin',
    '/usr/bin/openssl dgst -sha512 -sigopt rsa_padding_mode:pss -sigopt rsa_pss_saltlen:digest '
        '-sigopt rsa_mgf1_md:sha512 -verify signing.pub -signature signature.bin signed.bin',
    '/bin/sh installer.run --update-v2 "$clientDir"',
  ].join('\n');
}
