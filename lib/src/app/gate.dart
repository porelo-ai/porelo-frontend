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

  /// Whether this project can be asked about at all.
  ///
  /// Every gate method takes the project's file, so a project without one is listed and cannot be
  /// acted on. Saying that beats a dialog that opens on nothing.
  bool get reachable => project?.canBeActedOn ?? false;

  /// Reads what is waiting at [project]'s gate.
  Future<void> lookAt(FleetBackend backend, Project project) async {
    this.project = project;
    looking = null;
    diff = '';
    log = '';
    ranked = const <ReviewFile>[];
    asked = null;
    if (!project.canBeActedOn) {
      waiting = const <PendingPush>[];
      problem =
          '${project.name} is not a project this machine follows, so it has no gate to '
          'ask. Following its repository makes it one.';
      notifyListeners();
      return;
    }
    await _asking(() => _readAgain(backend, project.name));
  }

  /// Opens one waiting push, so it can be judged before it is forwarded.
  Future<void> look(FleetBackend backend, PendingPush push, {String? against}) async {
    looking = push;
    diff = '';
    log = '';
    ranked = const <ReviewFile>[];
    asked = null;
    notifyListeners();
    final file = project?.name;
    if (file == null || file.isEmpty) return;
    await _asking(() async {
      final review = await backend.reviewOf(file, push.name, against: against, repository: _where(push));
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
    await _asking(() async {
      // The commit that was reviewed, where the machine takes it: a push that moved since is then
      // refused, not forwarded unseen. An older Porelo is not sent it.
      final commit = push.commit.isNotEmpty && await _takesTheCommit(backend) ? push.commit : null;
      try {
        await backend.approve(file, push.name, branch, repository: _where(push), commit: commit);
      } on VarlinkException catch (refusal) {
        // What it holds now is read again, so the review shows it rather than what was read before.
        if (refusal.simpleName == 'MovedSinceReview') {
          looking = null;
          await _readAgain(backend, file);
        }
        rethrow;
      }
      said = '${push.subject} was forwarded to $branch.';
      looking = null;
      await _readAgain(backend, file);
    });
    // Once the call itself went through, that is what happened — whatever reading the gate again
    // then found.
    return said.isNotEmpty ? said : (problem ?? said);
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
