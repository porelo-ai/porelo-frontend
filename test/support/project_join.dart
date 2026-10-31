import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/project_join.dart';
import 'package:porelo_host/porelo_host.dart';

/// A key's `SHA256:` fingerprint, as the daemon answers the keys a follow pinned.
String pinnedAs(String key) =>
    'SHA256:${base64Encode(sha256.convert(base64Decode(key.split(' ')[1])).bytes).replaceAll('=', '')}';

/// Core's discovery as a test tells it.
class FakeDiscovery implements JoinDiscovery {
  /// What Core answers.
  List<JoinAdmission> answer = [];

  /// What Core throws instead of answering.
  Exception? refusal;

  @override
  Future<List<JoinAdmission>> admissions() async {
    if (refusal case final refused?) throw refused;
    return answer;
  }
}

/// The card tunnel and the account daemon, recording every call.
class FakeJoinHost implements JoinHost {
  /// Calls in order.
  final calls = <String>[];

  /// A tunnel failure to throw on the next connect.
  Exception? tunnelFails;

  /// A follow failure to throw on the next follow.
  Exception? followFails;

  /// What the daemon follows, by name.
  final following = <String, Followed>{};

  /// The revision the daemon confirms instead of the verified one.
  String? confirms;

  /// Whether the daemon confirms the follow as unverified.
  bool unverified = false;

  /// Whether a card tunnel is up, with the ssh configuration this desktop publishes for its card.
  bool up = true;

  /// Whether a watched card holds the person's key now.
  bool isCurrent = true;

  /// Whether a tunnel raised again comes up, or null to leave it as it is.
  bool? upOnRaise;

  /// Holds each connect until completed.
  Completer<void>? connectHeld;

  /// Holds each follow until completed.
  Completer<void>? followHeld;

  /// How the daemon's `Follow` ends: `APPLIED`, `UNCHANGED`, or a refusal such as `VAULT_LOCKED`.
  String outcome = 'APPLIED';

  @override
  Future<Machine> connect(JoinOffered offer) async {
    final host = offer.host;
    calls.add('connect ${host.name}');
    await connectHeld?.future;
    if (tunnelFails case final failure?) {
      tunnelFails = null;
      throw failure;
    }
    await Future<void>.delayed(Duration.zero);
    return Machine.fromHostCard(
      HostCardSsh(
        name: host.name,
        address: host.address,
        sshPort: host.sshPort,
        hostKey: host.sshHostKey,
        login: offer.login,
        publicKey: host.sshHostKey,
        webPort: 3000,
        gitPort: 3001,
        matrixPort: 8448,
      ),
      socketPath: '/unused',
      sshConfig: '/unused/${host.name}.conf',
    );
  }

  @override
  Future<Followed?> followed(Machine machine, String project) async => following[project];

  @override
  Future<bool> current(Machine machine) async => isCurrent;

  @override
  Future<void> raise(Machine machine) async {
    calls.add('raise ${machine.name}');
    up = upOnRaise ?? up;
  }

  @override
  bool ready(Machine machine) => up;

  @override
  Future<void> release(Machine machine) async => calls.add('release ${machine.name}');

  @override
  Future<Followed> follow(Machine machine, JoinOffered offer) async {
    calls.add('follow ${offer.project} ${offer.source} ${offer.signers.join(',')}');
    await followHeld?.future;
    if (followFails case final failure?) {
      followFails = null;
      throw failure;
    }
    // As the daemon answers `Follow`: its outcome and what it pinned, never the access commit or the signers in force,
    // which only `Following` answers.
    final pinned = [for (final signer in offer.signers) pinnedAs(signer)];
    if (outcome != 'APPLIED' && outcome != 'UNCHANGED') {
      return Followed(name: '', outcome: outcome, detail: 'the vault of this account is shut');
    }
    following[offer.project] = Followed(
      name: offer.project,
      url: offer.source,
      outcome: outcome,
      accessCommit: confirms ?? offer.revision,
      unverified: unverified,
      signers: pinned,
    );
    return Followed(name: '', outcome: outcome, commit: 'f' * 40, recorded: true, pinned: pinned);
  }
}
