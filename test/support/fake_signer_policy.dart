import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/signer_policy.dart';

/// Core's signer policy as a test tells it: the person's key, the lines in force, and the verdicts recorded.
class FakeSignerPolicy implements SignerPolicy {
  /// Constructor taking the person's login, their public key and the lines in force.
  FakeSignerPolicy({required this.login, required this.key, required this.allowedSigners});

  /// The person's login.
  String login;

  /// The person's public key, without a comment.
  String key;

  /// The allowed-signers lines in force, as Core would answer them.
  List<String> allowedSigners;

  /// What Core answers instead of a policy, such as an unsupported method or an unreadable answer.
  Exception? refusal;

  /// Core's recorded verdicts by revision; a revision not named here is unrecorded.
  final Map<String, String> verdicts = <String, String>{};

  /// Every question asked, in order.
  final List<String> asked = <String>[];

  @override
  Future<ProjectSigners> signers(String project) async {
    asked.add('signers $project');
    if (refusal case final refused?) throw refused;
    return ProjectSigners(login: login, key: key, allowedSigners: List<String>.of(allowedSigners));
  }

  @override
  Future<CommitVerdict> verdict(String project, String revision) async {
    asked.add('verdict $project $revision');
    if (refusal case final refused?) throw refused;
    return CommitVerdict(verdicts[revision] ?? 'unrecorded');
  }
}
