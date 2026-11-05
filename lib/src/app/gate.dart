import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'diff.dart';
import 'fleet_backend.dart';

/// What is waiting at one project's gate, and what is being made of it.
///
/// The gate is where work an agent finished sits until a person decides about it. Nothing leaves
/// the machine until somebody does: `Approve` is the only call in the whole contract that sends
/// anything anywhere, and it makes the caller name the branch rather than inferring one.
class Gate extends ChangeNotifier {
  /// Which project's gate this is, or null before one has been looked at.
  Project? project;

  /// Where the mirror is, once asked.
  String mirror = '';

  /// offline, gatekeeping or online.
  String mode = '';

  /// What is waiting, repository by repository — the project's own first — and within one in the
  /// order the gate answered.
  List<PendingPush> waiting = const <PendingPush>[];

  /// The repositories that were asked about and answered, the project's own first. Empty where the
  /// machine names none, which a Porelo older than repositories per project does.
  List<String> repositories = const <String>[];

  /// Whether something is being asked for right now.
  bool busy = false;

  /// Why the gate could not be read or acted on, in words. Null when nothing is wrong.
  String? problem;

  /// The push being looked at, or null.
  PendingPush? looking;

  /// Its diff, as the gate answered it.
  String diff = '';

  /// Its commit log over the same range.
  String log = '';

  /// The files that diff touches.
  List<ChangedFile> get changed => parseUnifiedDiff(diff);

  /// The push's files as the machine ranked them, in the order to show them: dangerous by kind
  /// first, the volume that is almost never a finding last. Empty from a Porelo older than the ranked
  /// review, which is then shown as before.
  List<ReviewFile> ranked = const <ReviewFile>[];

  /// What the task that pushed was asked: null where its task is gone from this machine, empty where
  /// it was started without an instruction. Shown beside what it touched, and never compared with it.
  String? asked;

  /// The forward the machine just refused for its ssh key, with the branch it was for; null otherwise.
  ({PushRefused refused, String branch})? keyRefused;

  /// The keys the machine's account has, from its ssh-agent and its files, read when a forward is
  /// refused for its key and again on [readKeys]. Never with a value.
  List<SshKey> keys = const <SshKey>[];

  /// Why the keys could not be listed, in words; null when they were.
  String? keysProblem;

  /// What trying each key answered, by [keyId].
  Map<String, TriedPush> tried = const <String, TriedPush>{};

  /// Why a key could not be tried, by [keyId].
  Map<String, String> notTried = const <String, String>{};

  /// How a key is named to the machine: an agent's by its fingerprint, a file's by its path.
  static String keyId(SshKey key) => key.fromTheAgent ? key.fingerprint : key.path;

  static String _source(SshKey key) => key.fromTheAgent ? 'AGENT' : 'FILE';

  /// Whether the diff shown leaves out changes at line ends, as the person asked.
  bool withoutLineEndings = false;

  /// Whether this machine's `Review` can leave out line ends; false until asked, and on an older one.
  bool servesWithoutLineEndings = false;

  /// Whether this project can be asked about at all.
  ///
  /// Every gate method takes the project's file, so a project without one is listed and cannot be
  /// acted on. Saying that beats a dialog that opens on nothing.
  bool get reachable => project?.canBeActedOn ?? false;

  /// Reads what is waiting at [project]'s gate.
  Future<void> lookAt(FleetBackend backend, Project project) async {
    this.project = project;
    looking = null;
    _forgetTheRefusal();
    diff = '';
    log = '';
    ranked = const <ReviewFile>[];
    asked = null;
    if (!project.canBeActedOn) {
      waiting = const <PendingPush>[];
      problem =
          '${project.name} is not on this machine, so it has no gate to '
          'ask.';
      notifyListeners();
      return;
    }
    await _asking(() => _readAgain(backend, project.name));
  }

  /// Opens one waiting push, so it can be judged before it is forwarded.
  Future<void> look(FleetBackend backend, PendingPush push, {String? against}) async {
    if (!identical(looking, push)) withoutLineEndings = false;
    looking = push;
    _forgetTheRefusal();
    diff = '';
    log = '';
    ranked = const <ReviewFile>[];
    asked = null;
    notifyListeners();
    final file = project?.name;
    if (file == null || file.isEmpty) return;
    _against = against;
    await _asking(() async {
      servesWithoutLineEndings = await _reviewTakes(backend, 'ignoreLineEndings');
      // Never sent to a machine that does not take it, which would refuse the whole review; what the
      // window says follows what was asked.
      withoutLineEndings = withoutLineEndings && servesWithoutLineEndings;
      final review = await backend.reviewOf(
        file,
        push.name,
        against: against,
        repository: _where(push),
        ignoreLineEndings: withoutLineEndings ? true : null,
      );
      diff = review.diff;
      log = review.log;
      ranked = review.files;
      asked = review.asked;
    });
  }

  /// Forwards the push being looked at onto [branch].
  Future<String> approve(FleetBackend backend, String branch) async {
    final file = project?.name;
    final push = looking;
    if (file == null || push == null) return '';
    var said = '';
    // A way through an earlier refusal is for that forward; this one is answered on its own.
    _forgetTheRefusal();
    await _asking(() async {
      // The commit that was reviewed, where the machine takes it: a push that moved since is then
      // refused, not forwarded unseen. An older Porelo is not sent it.
      final commit = push.commit.isNotEmpty && await _takesTheCommit(backend) ? push.commit : null;
      try {
        await backend.approve(file, push.name, branch, repository: _where(push), commit: commit);
      } on VarlinkException catch (refusal) {
        if (refusal.simpleName == 'PushRefused') {
          // Nothing went upstream; what to do about the key is shown beside the review, not as a line.
          keyRefused = (refused: PushRefused.from(refusal.parameters), branch: branch);
          tried = const <String, TriedPush>{};
          notTried = const <String, String>{};
          await _listKeys(backend);
          return;
        }
        // What it holds now is read again, so the review shows it rather than what was read before.
        if (refusal.simpleName == 'MovedSinceReview') {
          looking = null;
          await _readAgain(backend, file);
        }
        rethrow;
      }
      said = '${push.subject} was forwarded to $branch.';
      looking = null;
      _forgetTheRefusal();
      await _readAgain(backend, file);
    });
    // Once the call itself went through, that is what happened — whatever reading the gate again
    // then found.
    return said.isNotEmpty ? said : (problem ?? said);
  }

  /// Reads the account's keys again: one the agent took on since, from an unlocked KeePassXC, then shows.
  Future<void> readKeys(FleetBackend backend) async {
    busy = true;
    notifyListeners();
    try {
      await _listKeys(backend);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _listKeys(FleetBackend backend) async {
    try {
      keys = await backend.sshKeys();
      keysProblem = null;
    } on VarlinkException catch (refusal) {
      keys = const <SshKey>[];
      keysProblem = 'The machine did not list its keys: ${_wordsFor(refusal)}';
    } on VarlinkDisconnected catch (ex) {
      keys = const <SshKey>[];
      keysProblem = 'Lost contact with the machine: ${ex.message}';
    } on FeatureNotSupported {
      keys = const <SshKey>[];
      keysProblem = 'This machine’s Porelo cannot list its ssh keys.';
    }
  }

  /// Tries the refused forward with [key] alone, as a dry run: nothing is pushed and nothing kept.
  Future<void> tryKey(FleetBackend backend, SshKey key) async {
    final file = project?.name;
    final push = looking;
    final refusal = keyRefused;
    if (file == null || push == null || refusal == null) return;
    final id = keyId(key);
    busy = true;
    notifyListeners();
    String? why;
    try {
      final answer = await backend.credentialTryPush(
        file,
        repository: _where(push),
        refspec: 'refs/porelo/incoming/${push.name}:refs/heads/${refusal.branch}',
        source: _source(key),
        id: id,
      );
      tried = <String, TriedPush>{...tried, id: answer};
      notTried = <String, String>{...notTried}..remove(id);
    } on VarlinkException catch (refusal) {
      why = _wordsFor(refusal);
    } on VarlinkDisconnected catch (ex) {
      why = 'Lost contact with the machine: ${ex.message}';
    } on FeatureNotSupported {
      why = 'This machine’s Porelo cannot try a key on its own.';
    } finally {
      if (why != null) {
        notTried = <String, String>{...notTried, id: why};
        tried = <String, TriedPush>{...tried}..remove(id);
      }
      busy = false;
      notifyListeners();
    }
  }

  /// Keeps [key] for the refused forward's address, and only then forwards again onto the same branch.
  Future<String> keepKey(FleetBackend backend, SshKey key) async {
    final refusal = keyRefused;
    if (refusal == null || looking == null) return '';
    var kept = false;
    await _asking(() async {
      await backend.credentialDeclare(
        kind: 'SSH_KEY',
        match: refusal.refused.address,
        purpose: 'git',
        source: _source(key),
        id: keyId(key),
      );
      kept = true;
    });
    if (!kept) return problem ?? '';
    return approve(backend, refusal.branch);
  }

  void _forgetTheRefusal() {
    keyRefused = null;
    keys = const <SshKey>[];
    keysProblem = null;
    tried = const <String, TriedPush>{};
    notTried = const <String, String>{};
  }

  /// Reads the push being looked at again, with or without what changed at line ends.
  Future<void> showWithoutLineEndings(FleetBackend backend, bool without) async {
    final push = looking;
    if (push == null) return;
    withoutLineEndings = without;
    await look(backend, push, against: _against);
  }

  String? _against;

  Future<bool> _reviewTakes(FleetBackend backend, String parameter) async {
    try {
      final contract = await backend.contract();
      return RegExp(r'method Review\((.*?)\)\s*->', dotAll: true).firstMatch(contract)?.group(1)?.contains(parameter) ??
          false;
    } on Object {
      return false;
    }
  }

  Future<bool> _takesTheCommit(FleetBackend backend) async {
    try {
      final contract = await backend.contract();
      return RegExp(r'method Approve\((.*?)\)\s*->', dotAll: true).firstMatch(contract)?.group(1)?.contains('commit') ??
          false;
    } on Object {
      return false;
    }
  }

  /// Drops the request. The work stays in the mirror; only the asking is gone. The task it came
  /// from is told, with [reason] when a person gave one.
  Future<String> reject(FleetBackend backend, {String reason = ''}) async {
    final file = project?.name;
    final push = looking;
    if (file == null || push == null) return '';
    var said = '';
    await _asking(() async {
      final done = await backend.reject(file, push.name, repository: _where(push), reason: reason);
      final words = reason.trim().isEmpty ? '' : ', with your words';
      final told = switch (done.told) {
        true => ' Its task was told$words.',
        false => ' No task of that name is here any more, so nobody was told.',
        null => '',
      };
      said = '${push.subject} was dropped. The work is still in the mirror.$told';
      looking = null;
      _forgetTheRefusal();
      await _readAgain(backend, file);
    });
    // Once the call itself went through, that is what happened — whatever reading the gate again
    // then found.
    return said.isNotEmpty ? said : (problem ?? said);
  }

  /// The repository a push waits in, as a gate call takes it: none where none was asked about.
  static String? _where(PendingPush push) => push.repository.isEmpty ? null : push.repository;

  /// Asks every repository the project has, because **each has a gate of its own**:
  /// asking only the project's own would leave the work a task did anywhere else waiting where
  /// nobody is shown it.
  ///
  /// One repository that cannot be read is named, and does not hide what the others hold.
  Future<void> _readAgain(FleetBackend backend, String file) async {
    final names = project?.repositories ?? const <String>[];
    if (names.isEmpty) {
      final gate = await backend.gateOf(file);
      mirror = gate.mirror;
      mode = gate.mode;
      waiting = gate.pending;
      repositories = const <String>[];
      return;
    }
    final answers = await Future.wait(<Future<(String, GateState?, String?)>>[
      for (final name in names) _gateIn(backend, file, name),
    ]);
    final read = <(String, GateState)>[
      for (final (name, gate, _) in answers)
        if (gate != null) (name, gate),
    ];
    final unread = <String>[
      for (final (name, _, why) in answers)
        if (why != null) '$name could not be read: $why',
    ];
    // Mirror and mode as the project's own repository answers them, or the first that did.
    mirror = read.isEmpty ? '' : read.first.$2.mirror;
    mode = read.isEmpty ? '' : read.first.$2.mode;
    waiting = <PendingPush>[
      for (final (name, gate) in read)
        for (final push in gate.pending) push.inRepository(name),
    ];
    repositories = <String>[for (final (name, _) in read) name];
    if (unread.isNotEmpty) problem = unread.join(' ');
  }

  Future<(String, GateState?, String?)> _gateIn(FleetBackend backend, String file, String repository) async {
    try {
      return (repository, await backend.gateOf(file, repository: repository), null);
    } on VarlinkException catch (refusal) {
      return (repository, null, _wordsFor(refusal));
    } on VarlinkDisconnected catch (ex) {
      return (repository, null, 'lost contact with the machine: ${ex.message}');
    } on FeatureNotSupported catch (ex) {
      return (repository, null, '$ex');
    }
  }

  Future<void> _asking(Future<void> Function() ask) async {
    busy = true;
    problem = null;
    notifyListeners();
    try {
      await ask();
    } on VarlinkException catch (refusal) {
      // A named refusal is an answer: BranchRequired and ProjectRequired both land here, and both
      // are things somebody did rather than things that broke.
      problem = _wordsFor(refusal);
    } on VarlinkDisconnected catch (ex) {
      problem = 'Lost contact with the machine: ${ex.message}';
    } on FeatureNotSupported catch (ex) {
      problem = '$ex';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  static String _short(Object? commit) {
    final said = '${commit ?? ''}';
    return said.isEmpty ? 'another commit' : (said.length > 7 ? said.substring(0, 7) : said);
  }

  static String _wordsFor(VarlinkException refusal) => switch (refusal.simpleName) {
    'BranchRequired' => 'A branch has to be named. Nothing is forwarded onto a guess.',
    'ProjectRequired' => 'No project file was given, and every gate call takes one.',
    // The push moved after it was read: nothing went upstream, and what it holds now is unread.
    'MovedSinceReview' =>
      '${refusal.parameters['name'] ?? 'It'} moved since you reviewed it: you read '
          '${_short(refusal.parameters['reviewed'])}, and it holds ${_short(refusal.parameters['now'])} now. '
          'Nothing was forwarded. Open it again and review what it holds now.',
    // The branch holds a commit the reviewed work did not grow from: nothing was pushed, and the
    // machine never overwrites it. The next free name is the machine's own suggestion.
    'BranchExists' =>
      '${refusal.parameters['branch']} already holds '
          '${_short(refusal.parameters['at'])}, from earlier work. Nothing was forwarded. Forward it '
          'onto another branch, such as ${refusal.parameters['branch']}-2.',
    'Failed' => '${refusal.parameters['message'] ?? 'It did not work.'}',
    _ => 'Refused: ${refusal.simpleName}.',
  };
}
