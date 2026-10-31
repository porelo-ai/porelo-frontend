import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/project_join.dart';
import 'package:porelo_host/porelo_host.dart';

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

  @override
  Future<Machine> connect(PreparedHost host) async {
    calls.add('connect ${host.name}');
    if (tunnelFails case final failure?) {
      tunnelFails = null;
      throw failure;
    }
    return Machine(
      name: 'alice on ${host.name}',
      kind: 'host',
      hostProject: host.name,
      host: 'alice@${host.address}',
      socketPath: '/unused',
      remoteSocket: '/run/user/1007/porelo',
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
    );
  }
}
