import 'dart:io';

import 'package:porelo_host/porelo_host.dart' show HostFiles;

import 'machines.dart' show openSsh;
import 'run_here.dart';

/// The environment the check's Git calls run in: none of the person's or the system's Git configuration, so nothing
/// there chooses how a commit object is read.
const _isolatedGit = <String, String>{
  'GIT_CONFIG_GLOBAL': '/dev/null',
  'GIT_CONFIG_NOSYSTEM': '1',
  'GIT_TERMINAL_PROMPT': '0',
};

/// The check that a commit made here is signed with the person's own key.
///
/// A signature is checked with `ssh-keygen -Y` against the given allowed-signers lines at the present time, never
/// at the time a commit claims, which its signer chooses.
class CommitSigning {
  /// Constructor taking how programs are run.
  CommitSigning({RunHere? run}) : _run = run ?? runHere;

  final RunHere _run;

  static const _unsigned = WorkspaceRefused('The commit is not signed with the chosen key. Nothing was pushed.');

  /// Checks that [revision], a commit made here, is signed in namespace `git` with [signers]' key, which its
  /// allowed-signers lines name.
  Future<void> checkOwn(String folder, String revision, OwnSigner signers, {required Directory scratchIn}) async {
    final signer = await _acceptedNow(folder, revision, signers, scratchIn);
    if (signer != HostFiles.signingFingerprint(signers.key)) throw _unsigned;
  }

  /// Answers the fingerprint of the key that signed [revision] in namespace `git`, as [signers]' lines accept it now.
  Future<String> _acceptedNow(String folder, String revision, OwnSigner signers, Directory scratchIn) async {
    final raw = await _run('git', ['cat-file', 'commit', revision], inDirectory: folder, environment: _isolatedGit);
    if (raw.code != 0) throw _unsigned;
    // Git checks only the signature header of the repository's own hash; another one is never taken for it.
    final format = await _run(
      'git',
      ['rev-parse', '--show-object-format'],
      inDirectory: folder,
      environment: _isolatedGit,
    );
    final signed = _split(
      raw.out,
      header: switch (format.out.trim()) {
        'sha1' when format.code == 0 => 'gpgsig',
        'sha256' when format.code == 0 => 'gpgsig-sha256',
        _ => throw _unsigned,
      },
    );
    final scratch = await scratchIn.createTemp('porelo-signers-');
    try {
      final allowed = File('${scratch.path}/allowed_signers');
      await allowed.writeAsString('${signers.allowedSigners.join('\n')}\n');
      final signature = File('${scratch.path}/signature');
      await signature.writeAsString(signed.signature);
      final keygen = openSsh('ssh-keygen');
      final found = await _run(keygen, ['-Y', 'find-principals', '-s', signature.path, '-f', allowed.path]);
      if (found.code != 0) throw _unsigned;
      for (final principal in found.out.split('\n').map((line) => line.trim()).where(_isPrincipal)) {
        final verified = await _run(keygen, [
          '-Y',
          'verify',
          '-f',
          allowed.path,
          '-I',
          principal,
          '-n',
          'git',
          '-s',
          signature.path,
        ], input: signed.payload);
        final signer = RegExp(r' key (SHA256:[A-Za-z0-9+/]{43})').firstMatch('${verified.out}\n${verified.err}');
        if (verified.code == 0 && signer != null) return signer.group(1)!;
      }
      throw _unsigned;
    } on WorkspaceRefused {
      rethrow;
    } on Exception {
      throw _unsigned;
    } finally {
      await scratch.delete(recursive: true);
    }
  }

  static bool _isPrincipal(String principal) => RegExp(r'^[^\s\x00-\x1f\x7f-][^\s\x00-\x1f\x7f]*$').hasMatch(principal);

  /// Splits a raw commit object into its one SSH signature under [header] and the payload that signature covers,
  /// refusing a commit that carries a signature header of another hash.
  static ({String signature, String payload}) _split(String raw, {required String header}) {
    final payload = <String>[];
    final signature = <String>[];
    var headers = true;
    var inSignature = false;
    var signatures = 0;
    for (final line in raw.split('\n')) {
      if (headers && line.isEmpty) {
        headers = false;
      } else if (headers && (line.startsWith('gpgsig ') || line.startsWith('gpgsig-sha256 '))) {
        if (!line.startsWith('$header ')) throw _unsigned;
        signatures++;
        inSignature = true;
        signature.add(line.substring(line.indexOf(' ') + 1));
        continue;
      } else if (headers && inSignature && line.startsWith(' ')) {
        signature.add(line.substring(1));
        continue;
      }
      inSignature = false;
      payload.add(line);
    }
    if (signatures != 1 || signature.first != '-----BEGIN SSH SIGNATURE-----') throw _unsigned;
    return (signature: '${signature.join('\n')}\n', payload: payload.join('\n'));
  }
}

/// The person's own key and the allowed-signers lines a commit made here is checked against.
class OwnSigner {
  /// Constructor taking both.
  const OwnSigner({required this.key, required this.allowedSigners});

  /// The person's public key, its type and its key without a comment: the one a commit made here is signed with.
  final String key;

  /// Git's allowed-signers lines the commit is checked against, verbatim, never rewritten here.
  final List<String> allowedSigners;
}
