import 'dart:io';

import 'package:porelo_frontend/client.dart';
import 'package:porelo_host/porelo_host.dart' show HostFiles;

import 'machines.dart' show openSsh;
import 'run_here.dart';
import 'signer_policy.dart';

/// The environment every Git call of a signed checkout runs in: none of the person's or the system's Git
/// configuration, so nothing there chooses how, or with what, a commit is signed.
const isolatedGit = <String, String>{
  'GIT_CONFIG_GLOBAL': '/dev/null',
  'GIT_CONFIG_NOSYSTEM': '1',
  'GIT_TERMINAL_PROMPT': '0',
};

/// Commits signed with the person's key through their SSH agent, and accepted only as Core's signer policy says.
///
/// Signing names the person's public key as `key::`, so `ssh-keygen` asks the agent and no private key file is
/// read. A signature is checked with `ssh-keygen -Y` against Core's allowed-signers lines at the present time, never
/// at the time a commit claims, which its signer chooses.
class CommitSigning {
  /// Constructor taking Core's policy, absent where none is available, and how programs are run.
  CommitSigning(this.policy, {RunHere? run}) : _run = run ?? runHere;

  /// Core's signer policy; without it nothing is signed or accepted.
  final SignerPolicy? policy;

  final RunHere _run;

  static const _unsigned = WorkspaceRefused(
    'The commit is not signed by a signer Porelo accepts for this project. Nothing was moved or pushed.',
  );

  /// Core's signers for [project], refused when there is no policy or Core answers nothing usable.
  Future<ProjectSigners> signersFor(String project) async {
    final policy = this.policy;
    if (policy == null) throw const WorkspaceRefused(_noPolicy);
    try {
      return await policy.signers(project);
    } on FeatureNotSupported {
      throw const WorkspaceRefused(_noPolicy);
    } on Exception {
      throw const WorkspaceRefused('Porelo did not say who signs for this project. Nothing was signed or pushed.');
    }
  }

  static const _noPolicy =
      'Porelo on this computer cannot say yet who signs for this project, so nothing is signed or pushed.';

  /// The options that sign one commit with the person's key from [signers] through the agent, authored as [login].
  static List<String> signingOptions(ProjectSigners signers, {required String login}) => [
    '-c',
    'gpg.format=ssh',
    '-c',
    'gpg.ssh.program=${openSsh('ssh-keygen')}',
    '-c',
    'user.signingkey=key::${signers.key}',
    '-c',
    'commit.gpgsign=true',
    '-c',
    'user.name=$login',
    '-c',
    'user.email=$login@users.noreply.github.com',
  ];

  /// Checks that [revision], a commit made here, is signed with the person's key and accepted by the lines in force.
  Future<void> checkOwn(String folder, String revision, ProjectSigners signers, {required Directory scratchIn}) async {
    final signer = await _acceptedNow(folder, revision, signers, scratchIn);
    if (signer != HostFiles.signingFingerprint(signers.key)) throw _unsigned;
  }

  /// Accepts [revision], a commit that arrived from elsewhere, by Core's recorded verdict, or, where Core recorded
  /// none, as a commit arriving now.
  Future<void> checkArrived(
    String project,
    String folder,
    String revision,
    ProjectSigners signers, {
    required Directory scratchIn,
  }) async {
    final policy = this.policy;
    if (policy == null) throw const WorkspaceRefused(_noPolicy);
    final CommitVerdict verdict;
    try {
      verdict = await policy.verdict(project, revision);
    } on Exception {
      throw const WorkspaceRefused('Porelo did not say whether it accepted this commit. Nothing was moved.');
    }
    if (verdict.accepted) return;
    if (!verdict.unrecorded) throw _unsigned;
    await _acceptedNow(folder, revision, signers, scratchIn);
  }

  /// Answers the fingerprint of the key that signed [revision] in namespace `git`, as Core's lines accept it now.
  Future<String> _acceptedNow(String folder, String revision, ProjectSigners signers, Directory scratchIn) async {
    final raw = await _run('git', ['cat-file', 'commit', revision], inDirectory: folder, environment: isolatedGit);
    if (raw.code != 0) throw _unsigned;
    final signed = _split(raw.out);
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

  /// Splits a raw commit object into its one SSH signature and the payload that signature covers.
  static ({String signature, String payload}) _split(String raw) {
    final payload = <String>[];
    final signature = <String>[];
    var headers = true;
    var inSignature = false;
    var signatures = 0;
    for (final line in raw.split('\n')) {
      if (headers && line.isEmpty) {
        headers = false;
      } else if (headers && (line.startsWith('gpgsig ') || line.startsWith('gpgsig-sha256 '))) {
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
