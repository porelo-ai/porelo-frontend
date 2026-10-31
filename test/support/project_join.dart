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

  @override
  Future<Machine> connect(PreparedHost host) async {
    calls.add('connect ${host.name}');
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
        login: 'porelo-alice',
        publicKey: host.sshHostKey,
        uid: 1007,
        returnSocket: '/run/porelo-host/people/porelo-alice/return.sock',
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
  Future<Followed> follow(Machine machine, JoinOffered offer) async {
    calls.add('follow ${offer.project} ${offer.source} ${offer.signers.join(',')}');
    if (followFails case final failure?) {
      followFails = null;
      throw failure;
    }
    return following[offer.project] = Followed(
      name: offer.project,
      url: offer.source,
      commit: confirms ?? offer.revision,
      unverified: unverified,
      signers: [for (final signer in offer.signers) pinnedAs(signer)],
    );
  }
}
