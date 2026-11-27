import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_host/porelo_host.dart' show quoteForAShell;

import 'diff.dart';
import 'fleet_backend.dart';
import 'hand_in.dart' show HandingIn;

/// A push that left the list of waiting ones because a task holding the right to reject rejected it, with who and when.
///
/// Said to the person so a push a task dropped is never taken for one that vanished or for their own refusal.
@immutable
class PushRejected {
  /// Constructor taking every field.
  const PushRejected({required this.task, required this.subject, required this.name, this.repository = '', this.at});

  /// The task's name, cut to printable ASCII and at most 64 characters, since the machine chose it.
  final String task;

  /// First line of the pushed commit's message.
  final String subject;

  /// The push's name at the gate.
  final String name;

  /// The repository it waited in; empty where the gate was asked about none.
  final String repository;

  /// When the task rejected it, UTC, RFC 3339, as the machine wrote it; null where it did not say or wrote no instant.
  final String? at;

  /// What tells the push apart: the same name can wait in two repositories.
  String get id => repository.isEmpty ? name : '$repository:$name';

  /// The day and the time of day it was rejected, here, or null where the machine gave none: the day too, since a
  /// notice stays until it is dismissed and a time alone would read as today's.
  String? get when {
    final local = switch (at) {
      final at? => DateTime.tryParse(at)?.toLocal(),
      null => null,
    };
    if (local == null) return null;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} at ${two(local.hour)}:${two(local.minute)}';
  }

  /// What the machine named, kept to what a line can show, or null where nothing printable is left.
  static String? taskNamed(String raw) {
    final shown = String.fromCharCodes(raw.codeUnits.where((unit) => unit >= 0x20 && unit <= 0x7e));
    final cut = shown.length > 64 ? shown.substring(0, 64) : shown;
    return cut.trim().isEmpty ? null : cut;
  }

  @override
  bool operator ==(Object other) =>
      other is PushRejected &&
      other.task == task &&
      other.subject == subject &&
      other.name == name &&
      other.repository == repository &&
      other.at == at;

  @override
  int get hashCode => Object.hash(task, subject, name, repository, at);
}

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

  /// The pushes a task rejected that were waiting here before, newest last, until the person dismisses each or
  /// another project's gate is opened.
  List<PushRejected> get rejectedByTasks => List<PushRejected>.unmodifiable(_rejectedByTasks);
  final List<PushRejected> _rejectedByTasks = <PushRejected>[];

  /// Takes one notice of [rejected] away.
  void dismissRejection(PushRejected rejected) {
    if (_rejectedByTasks.remove(rejected)) notifyListeners();
  }

  /// The pushes this window itself approved or rejected since the list was last read: gone from it on the
  /// person's word, never asked about.
  final Set<String> _decidedHere = <String>{};

  /// Whether something is being asked for right now.
  bool busy = false;

  /// Why the gate could not be read or acted on, in words. Null when nothing is wrong.
  String? problem;

  /// The repositories whose gate could not be read, each with why in words; empty when all were.
  List<({String name, String words})> unread = const <({String name, String words})>[];

  /// How many repositories' gates are being read right now; 0 when none are.
  int reading = 0;

  /// [problem] where it says more than which repositories could not be read, which [unread] says.
  String? get otherProblem => problem == _unreadSaid ? null : problem;

  String? _unreadSaid;

  /// The push being looked at, or null.
  PendingPush? looking;

  /// Its diff as far as it is read: the gate's first page, and each page read since, joined.
  String diff = '';

  /// The files that diff touches, the last of them in part while [diffNext] is not null.
  List<ChangedFile> get changed {
    final parsed = _parsed;
    if (parsed != null && identical(parsed.$1, diff)) return parsed.$2;
    final files = parseUnifiedDiff(diff);
    _parsed = (diff, files);
    return files;
  }

  (String, List<ChangedFile>)? _parsed;

  /// Where the diff's next page starts, as the machine named it; null where none is to be read, because
  /// the diff is whole or the rest of it could not be read.
  int? diffNext;

  /// How many bytes of the diff are read, in UTF-8.
  int diffRead = 0;

  /// How many bytes the whole diff has, as the machine counted them; null where it does not say.
  int? diffBytes;

  /// Why the rest of the diff is not read, in words; null while it can be, or is whole.
  String? diffStopped;

  /// Whether a page of the diff is being read now.
  bool readingDiff = false;

  /// Where the machine cut the diff to fit one answer; null where it did not.
  ReviewCut? cut;

  /// The commit this review is of, as the machine named it, which forwarding sends; null until a review
  /// that names one is read.
  String? get reviewed => _read?.commit;

  /// Whether the push's file list and commits were read whole; false while they are read, and where a
  /// page of them could not be read or did not fit what the machine said.
  bool listsWhole = false;

  /// Whether the diff shown is all of it: nothing left to read, nothing stopped and nothing cut.
  bool get diffWhole => diffNext == null && diffStopped == null && cut == null;

  /// Whether the diff goes on past what is read, so the last file read may be read in part. A cut diff ends
  /// at a file boundary, so it does not.
  bool get diffContinues => diffNext != null || diffStopped != null;

  /// Whether a `Review` answer is held for the push looked at.
  bool get reviewHeld => _read != null;

  /// How much of the diff is read, in words, where it is not whole; null where it is.
  String? get diffReadWords {
    if (diffWhole) return null;
    final whole = diffBytes;
    final cut = this.cut;
    if (whole != null && cut == null) {
      return '${HandingIn.inWords(diffRead)} of ${HandingIn.inWords(whole)} of the diff read';
    }
    if (cut != null) {
      return 'The diff holds the patches of ${cut.shownFiles} of ${cut.shownFiles + cut.omittedFiles} files; '
          'the machine left the others out';
    }
    return 'Only part of the diff is read';
  }

  /// Why the push cannot be forwarded from here now, in words; null where it can.
  String? get forwardRefused {
    if (looking == null) return 'No push is open.';
    final read = _read;
    if (read == null) {
      return busy
          ? 'Its review is still being read.'
          : 'Its review could not be read, so it is not forwarded from here.';
    }
    if (!listsWhole) return '$notWholeWords, so it is not forwarded from here.';
    if (read.commit == null) {
      return 'The machine did not name the commit this review is of, so it is not forwarded from here.';
    }
    // A page that answers that the push moved would make what was decided on another commit's review.
    if (readingDiff) return 'The next part of the diff is being read.';
    return null;
  }

  /// Said in place of the files where the machine's list of them, or of the commits, is not whole.
  static const notWholeWords = "The machine's list of what this push changes could not be read whole";

  /// The one Review answer being shown, and what every page of it is asked with.
  _ReviewRead? _read;

  /// Which look is the newest: bumped by every look, and by the line-end switch, which looks again.
  int _looks = 0;

  /// The push's files as the machine ranked them, in the order to show them: dangerous by kind
  /// first, the volume that is almost never a finding last. Empty from a Porelo older than the ranked
  /// review, which is then shown as before.
  List<ReviewFile> ranked = const <ReviewFile>[];

  /// What the task that pushed was asked: null where its task is gone from this machine, empty where
  /// it was started without an instruction. Shown beside what it touched, and never compared with it.
  String? asked;

  /// The push's commits, newest first, with who made each: null until reviewed, and where the machine
  /// does not say, which the review card then says.
  List<ReviewCommit>? commits;

  /// The review summary of the push looked at, at the commit its review is of; null where no review naming a commit
  /// is held, which shows no counts at all.
  ChecksRead? checks;

  /// Each waiting push's review summary at the commit it names, by [PendingPush.id] and commit; a push without one
  /// shows no counts.
  ChecksRead? checksOf(PendingPush push) => push.commit.isEmpty ? null : _listChecks[_checksKey(push)];

  Map<String, ChecksRead> _listChecks = const <String, ChecksRead>{};

  static String _checksKey(PendingPush push) => '${push.id}@${push.commit}';

  /// Which read of the list's summaries is the newest: an older one that answers last is dropped.
  int _listSummaries = 0;

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
    // Another project's or machine's waiting pushes are never shown under this one's name while it is asked.
    if (this.project?.name != project.name || !identical(_from, backend)) {
      waiting = const <PendingPush>[];
      repositories = const <String>[];
      mirror = '';
      mode = '';
      _listChecks = const <String, ChecksRead>{};
      _rejectedByTasks.clear();
      _decidedHere.clear();
    }
    final round = ++_round;
    _from = backend;
    this.project = project;
    looking = null;
    _forgetTheRefusal();
    _forgetTheReview();
    unread = const <({String name, String words})>[];
    if (!project.canBeActedOn) {
      waiting = const <PendingPush>[];
      problem =
          '${project.name} is not on this machine, so it has no gate to '
          'ask.';
      notifyListeners();
      return;
    }
    await _asking(() => _readAgain(backend, project.name, round: round), round: round);
  }

  void _forgetTheReview() {
    _read = null;
    diff = '';
    _parsed = null;
    diffNext = null;
    diffRead = 0;
    diffBytes = null;
    diffStopped = null;
    readingDiff = false;
    _diffPages = 0;
    cut = null;
    listsWhole = false;
    ranked = const <ReviewFile>[];
    asked = null;
    commits = null;
    checks = null;
  }

  /// Opens one waiting push, so it can be judged before it is forwarded.
  ///
  /// Every page of its files and commits is read before it is drawn, so a list is never taken for the
  /// whole while it is not; its diff keeps its first page, and [readMoreDiff] reads on.
  Future<void> look(FleetBackend backend, PendingPush push, {String? against}) =>
      _look(backend, push, against: against, afterAMove: false);

  Future<void> _look(FleetBackend backend, PendingPush push, {String? against, required bool afterAMove}) async {
    if (!identical(looking, push)) withoutLineEndings = false;
    looking = push;
    final looks = ++_looks;
    _forgetTheRefusal();
    _forgetTheReview();
    notifyListeners();
    final file = project?.name;
    if (file == null || file.isEmpty) return;
    _against = against;
    final round = _round;
    // A push of a project no longer shown, or one looked at before the newest look, is not drawn.
    bool current() => round == _round && looks == _looks;
    busy = true;
    problem = null;
    notifyListeners();
    try {
      servesWithoutLineEndings = await _reviewTakes(backend, 'ignoreLineEndings');
      if (!current()) return;
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
      if (!current()) return;
      final paged = review.paged;
      final read = _ReviewRead(
        project: file,
        name: push.name,
        repository: _where(push),
        commit: review.commit == null || review.commit!.isEmpty ? null : review.commit,
        base: paged?.base ?? '',
        ignoreLineEndings: withoutLineEndings,
        files: paged?.files,
        commits: paged?.commits,
        looks: looks,
        afterAMove: afterAMove,
      );
      _read = read;
      // Read beside the lists, at the commit this review is of; none where it names none.
      if (read.commit case final commit?) {
        checks = const ChecksRead.reading();
        unawaited(() async {
          final summary = await _summaryOf(backend, file, push.name, read.repository, commit);
          if (!current() || !identical(_read, read)) return;
          checks = summary;
          notifyListeners();
        }());
      }
      asked = review.asked;
      cut = review.cut;
      diff = review.diff;
      diffRead = utf8.encode(review.diff).length;
      diffBytes = paged?.diffBytes;
      diffNext = paged?.diffNext;
      if (diffNext != null && read.commit == null) {
        diffNext = null;
        diffStopped = 'The machine did not name the commit this review is of, so the rest of the diff cannot be asked.';
      }
      final files = await _allOf(backend, read, 'files', review.files, paged?.filesNext, current);
      if (!current()) return;
      // Once a page of the files could not be read, nothing more of this review is asked.
      final commits = files == null
          ? null
          : await _allOf(
              backend,
              read,
              'commits',
              review.commits ?? const <ReviewCommit>[],
              paged?.commitsNext,
              current,
            );
      if (!current()) return;
      if (files == null || commits == null) {
        listsWhole = false;
        if (diffNext != null) {
          diffNext = null;
          diffStopped = 'nothing more of this review is asked once its list of files or commits could not be read.';
        }
        if (afterAMove) problem = '${_movedWords(push)} ${problem ?? ''}'.trim();
        return;
      }
      ranked = files;
      // Absent from an older machine stays absent, never an empty list.
      this.commits = review.commits == null && paged == null ? null : commits;
      listsWhole = true;
      if (afterAMove) problem = _movedWords(push);
    } on VarlinkException catch (refusal) {
      // A move answered to Review itself is said, never read again from here: that would be a loop.
      if (current()) problem = _wordsFor(refusal);
    } on VarlinkDisconnected catch (ex) {
      if (current()) problem = 'Lost contact with the machine: ${ex.message}';
    } on FeatureNotSupported catch (ex) {
      if (current()) problem = '$ex';
    } on FormatException catch (ex) {
      if (current()) problem = _machinesFault(ex);
    } finally {
      if (current()) {
        busy = false;
        notifyListeners();
      }
    }
  }

  /// Every page of [part] (`files` or `commits`) after [first], joined in order, or null where a page could not
  /// be read or did not fit what the machine said, which [problem] then says; nothing more is asked after that.
  Future<List<T>?> _allOf<T>(
    FleetBackend backend,
    _ReviewRead read,
    String part,
    List<T> first,
    int? next,
    bool Function() current,
  ) async {
    final size = part == 'files' ? read.files : read.commits;
    if (size == null) return first;
    final joined = <T>[...first];
    var from = next;
    var pages = 0;
    String? breach;
    while (from != null) {
      final commit = read.commit;
      if (commit == null) {
        problem = 'The machine did not name the commit this review is of, so the rest of its $part cannot be asked.';
        return null;
      }
      if (++pages > _mostPages) {
        breach = 'it gave more than $_mostPages pages of $part';
        break;
      }
      final ReviewPage page;
      try {
        page = await backend.reviewPageOf(
          read.project,
          read.name,
          repository: read.repository,
          commit: commit,
          against: read.base,
          ignoreLineEndings: read.ignoreLineEndings,
          part: part,
          from: from,
        );
      } on VarlinkException catch (refusal) {
        if (!current()) return null;
        if (refusal.simpleName == 'MovedSinceReview' && !read.afterAMove && looking != null) {
          await _readAgainAfterAMove(backend, read, current);
          return null;
        }
        problem = '$notWholeWords: ${_wordsFor(refusal)}';
        return null;
      } on VarlinkDisconnected catch (ex) {
        if (current()) problem = '$notWholeWords: lost contact with the machine: ${ex.message}';
        return null;
      } on FeatureNotSupported catch (ex) {
        if (current()) problem = '$notWholeWords: $ex';
        return null;
      } on FormatException catch (ex) {
        if (current()) problem = '$notWholeWords. ${_machinesFault(ex)}';
        return null;
      }
      if (!current()) return null;
      final entries = (part == 'files' ? page.files : page.commits)?.cast<T>() ?? <T>[];
      final after = page.next;
      if (entries.isEmpty) {
        breach = 'a page of $part held none';
      } else if (after != null && after <= from) {
        breach = 'a page of $part named a next one that is not further on';
      } else if (joined.length + entries.length > size) {
        breach = 'it gave more $part than the $size it counted';
      } else if ((after == null) != (joined.length + entries.length == size)) {
        breach = after == null
            ? 'it ended its $part at ${joined.length + entries.length} of the $size it counted'
            : 'it named a next page of $part after all ${joined.length + entries.length}';
      }
      if (breach != null) break;
      joined.addAll(entries);
      from = after;
    }
    if (breach == null && joined.length != size) {
      breach = 'it gave ${joined.length} $part of the $size it counted';
    }
    if (breach != null) {
      problem = '$notWholeWords. ${_machinesFault(FormatException(breach))}';
      return null;
    }
    return joined;
  }

  /// At most this many pages of one part are asked for one review: a machine that never ends a part is not
  /// asked forever.
  static const _mostPages = 10000;

  /// Reads the next page of the diff and puts it after what is read; one page at a time, and an answer for
  /// a review no longer shown is dropped.
  Future<void> readMoreDiff(FleetBackend backend) async {
    final read = _read;
    final from = diffNext;
    final commit = read?.commit;
    if (read == null || from == null || commit == null || readingDiff) return;
    bool current() => identical(_read, read) && read.looks == _looks;
    readingDiff = true;
    problem = null;
    notifyListeners();
    try {
      final page = await backend.reviewPageOf(
        read.project,
        read.name,
        repository: read.repository,
        commit: commit,
        against: read.base,
        ignoreLineEndings: read.ignoreLineEndings,
        part: 'diff',
        from: from,
      );
      if (!current()) return;
      final text = page.text ?? '';
      final bytes = utf8.encode(text).length;
      final after = page.next;
      final whole = diffBytes;
      final String? breach;
      if (bytes == 0) {
        breach = 'a page of the diff held nothing';
      } else if (after != null && after <= from) {
        breach = 'a page of the diff named a next one that is not further on';
      } else if (whole != null && diffRead + bytes > whole) {
        breach = 'it gave more of the diff than the ${HandingIn.inWords(whole)} it counted';
      } else if (whole != null && (after == null) != (diffRead + bytes == whole)) {
        breach = after == null
            ? 'it ended the diff at ${HandingIn.inWords(diffRead + bytes)} of the ${HandingIn.inWords(whole)} it counted'
            : 'it named a next page of the diff after all ${HandingIn.inWords(whole)}';
      } else if (++_diffPages > _mostPages) {
        breach = 'it gave more than $_mostPages pages of the diff';
      } else {
        breach = null;
      }
      if (breach != null) {
        _stopTheDiff(_machinesFault(FormatException(breach)));
        return;
      }
      diff = '$diff$text';
      diffRead += bytes;
      diffNext = after;
    } on VarlinkException catch (refusal) {
      if (!current()) return;
      if (refusal.simpleName == 'MovedSinceReview' && !read.afterAMove && looking != null) {
        // The old review is no longer shown or asked from while the push is read again: no page of its
        // commit can be asked meanwhile, and nothing of it is forwarded.
        _forgetTheReview();
        busy = true;
        notifyListeners();
        bool still() => read.looks == _looks;
        try {
          await _readAgainAfterAMove(backend, read, still);
        } on VarlinkException catch (again) {
          if (still()) problem = _wordsFor(again);
        } on VarlinkDisconnected catch (ex) {
          if (still()) problem = 'Lost contact with the machine: ${ex.message}';
        } on FeatureNotSupported catch (ex) {
          if (still()) problem = '$ex';
        } finally {
          if (still()) {
            busy = false;
            notifyListeners();
          }
        }
        return;
      }
      // Asked again it would be refused again: said, and not asked any more for this review.
      _stopTheDiff(_wordsFor(refusal));
    } on FeatureNotSupported catch (ex) {
      if (current()) _stopTheDiff('$ex');
    } on FormatException catch (ex) {
      if (current()) _stopTheDiff(_machinesFault(ex));
    } on VarlinkDisconnected catch (ex) {
      // The same page may be asked again once the machine answers.
      if (current()) problem = 'Lost contact with the machine: ${ex.message}';
    } finally {
      if (current()) {
        readingDiff = false;
        notifyListeners();
      }
    }
  }

  int _diffPages = 0;

  void _stopTheDiff(String why) {
    diffNext = null;
    diffStopped = why;
    problem = 'The rest of the diff was not read: $why';
  }

  /// The push moved since its review was read: what waits is read again from the gate's list and its review
  /// from the top, once, and the person is told.
  Future<void> _readAgainAfterAMove(FleetBackend backend, _ReviewRead read, bool Function() current) async {
    final file = project?.name;
    final push = looking;
    if (file == null || push == null) return;
    await _readAgain(backend, file);
    if (!current()) return;
    final now = waiting.where((each) => each.name == push.name && each.repository == push.repository).firstOrNull;
    if (now == null) {
      looking = null;
      _forgetTheReview();
      final rejected = _rejectedByTasks.where((each) => each.id == push.id).lastOrNull;
      problem = rejected == null
          ? '${push.subject} moved since it was read, and no longer waits at the gate.'
          : '${push.subject} moved since it was read: the task ${rejected.task} rejected it, so it no longer waits '
                'at the gate.';
      notifyListeners();
      return;
    }
    // Kept as the push looked at, so the line-end choice stays with it.
    looking = now;
    await _look(backend, now, against: _against, afterAMove: true);
  }

  static String _movedWords(PendingPush push) =>
      '${push.subject} moved since it was read: what it holds now is read again from the top.';

  static String _machinesFault(FormatException ex) =>
      'The machine answered this review in a way it never should (${ex.message}); nothing more is asked of it '
      'for this review.';

  /// Forwards the push being looked at onto [branch].
  ///
  /// Sends the commit the review shown is of, never the one the waiting push named before it was read: a
  /// push that moved since is then refused, not forwarded unseen.
  Future<({bool forwarded, String said})> approve(FleetBackend backend, String branch) async {
    final file = project?.name;
    final push = looking;
    if (file == null || push == null) return (forwarded: false, said: '');
    final refused = forwardRefused;
    final commit = reviewed;
    if (refused != null || commit == null) return (forwarded: false, said: refused ?? '');
    var said = '';
    // A way through an earlier refusal is for that forward; this one is answered on its own.
    _forgetTheRefusal();
    await _asking(() async {
      final ForwardedPush answer;
      try {
        answer = await backend.approve(file, push.name, branch, repository: _where(push), commit: commit);
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
      said = answer.branch.isEmpty
          ? '${push.subject} was forwarded.'
          : '${push.subject} was forwarded to ${answer.branch}.';
      final pullRequest = answer.pullRequest;
      if (pullRequest != null && pullRequest.isNotEmpty) said = '$said Pull request: $pullRequest.';
      _decidedHere.add(push.id);
      looking = null;
      _forgetTheRefusal();
      await _readAgain(backend, file);
    });
    // Once the call itself went through, that is what happened — whatever reading the gate again
    // then found.
    return (forwarded: said.isNotEmpty, said: said.isNotEmpty ? said : (problem ?? said));
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
  Future<({bool forwarded, String said})> keepKey(FleetBackend backend, SshKey key) async {
    final refusal = keyRefused;
    if (refusal == null || looking == null) return (forwarded: false, said: '');
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
    if (!kept) return (forwarded: false, said: problem ?? '');
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
      _decidedHere.add(push.id);
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
  Future<void> _readAgain(FleetBackend backend, String file, {int? round}) async {
    final mine = round ?? _round;
    final names = project?.repositories ?? const <String>[];
    unread = const <({String name, String words})>[];
    _unreadSaid = null;
    reading = names.isEmpty ? 1 : names.length;
    notifyListeners();
    final before = waiting;
    try {
      await _readEach(backend, file, names, mine);
      if (mine == _round) unawaited(_readSummaries(backend, file, mine));
    } finally {
      if (mine == _round) reading = 0;
    }
    // Only a list that was replaced by this read says what is gone from it.
    if (mine != _round || identical(before, waiting)) return;
    final decided = Set<String>.of(_decidedHere);
    _decidedHere.clear();
    final readIn = names.isEmpty ? const <String>{''} : repositories.toSet();
    final gone = <PendingPush>[
      for (final push in before)
        if (readIn.contains(push.repository) &&
            !decided.contains(push.id) &&
            !waiting.any((each) => each.id == push.id))
          push,
    ];
    await Future.wait(<Future<void>>[for (final push in gone) _askWhyGone(backend, file, push, mine)]);
  }

  /// Asks the machine how a push that left the list ended, and keeps a notice where a task rejected it.
  ///
  /// An extra question: a refusal, a machine without the method, a lost connection or an answer that does not
  /// say a task rejected it leaves no notice, and never hides the list or fails the read.
  Future<void> _askWhyGone(FleetBackend backend, String file, PendingPush push, int round) async {
    final PushEnd end;
    try {
      end = await backend.pushEnd(file, push.name, repository: _where(push));
    } on Exception {
      return;
    }
    if (round != _round || !identical(_from, backend) || project?.name != file) return;
    final by = end.rejectedBy;
    if ((end.decision != 'REJECTED' && end.decision != 'RETURNED') || by == null) return;
    final task = PushRejected.taskNamed(by);
    if (task == null) return;
    final since = end.decisionSince;
    final rejected = PushRejected(
      task: task,
      subject: push.subject,
      name: push.name,
      repository: push.repository,
      at: since != null && DateTime.tryParse(since) != null ? since : null,
    );
    if (_rejectedByTasks.contains(rejected)) return;
    _rejectedByTasks
      ..removeWhere((each) => each.id == rejected.id)
      ..add(rejected);
    notifyListeners();
  }

  /// Reads each waiting push's summary at the commit it names, all at once; what an older read answers after a newer
  /// one began is dropped, and a push no longer waiting keeps none.
  Future<void> _readSummaries(FleetBackend backend, String file, int round) async {
    final generation = ++_listSummaries;
    bool current() => round == _round && generation == _listSummaries;
    final pushes = <PendingPush>[
      for (final push in waiting)
        if (push.commit.isNotEmpty) push,
    ];
    // A row already read at the same commit keeps its counts until the new answer; a new commit starts as reading.
    final before = _listChecks;
    _listChecks = <String, ChecksRead>{
      for (final push in pushes) _checksKey(push): before[_checksKey(push)] ?? const ChecksRead.reading(),
    };
    notifyListeners();
    final read = await Future.wait(<Future<ChecksRead>>[
      for (final push in pushes) _summaryOf(backend, file, push.name, _where(push), push.commit),
    ]);
    if (!current()) return;
    _listChecks = <String, ChecksRead>{for (final (place, push) in pushes.indexed) _checksKey(push): read[place]};
    notifyListeners();
  }

  /// One push's summary, or why it is not there: an older machine's missing method reads "not reported", and a
  /// refusal its own words, never zeros.
  Future<ChecksRead> _summaryOf(
    FleetBackend backend,
    String file,
    String name,
    String? repository,
    String commit,
  ) async {
    try {
      return ChecksRead.read(await backend.reviewSummaryOf(file, name, repository: repository, commit: commit));
    } on FeatureNotSupported {
      return const ChecksRead.unread(ChecksRead.notReported);
    } on VarlinkException catch (refusal) {
      return ChecksRead.unread('Checks could not be read: ${_wordsFor(refusal)}');
    } on VarlinkDisconnected catch (ex) {
      return ChecksRead.unread('Checks could not be read: lost contact with the machine: ${ex.message}');
    } on FormatException catch (ex) {
      return ChecksRead.unread('Checks could not be read. ${_machinesFault(ex)}');
    } on Object catch (failure) {
      // Whatever else went wrong ends the read with its words: no row, and no row read beside it, stays reading.
      return ChecksRead.unread('Checks could not be read: $failure');
    }
  }

  Future<void> _readEach(FleetBackend backend, String file, List<String> names, int round) async {
    if (names.isEmpty) {
      final gate = await backend.gateOf(file);
      if (round != _round) return;
      mirror = gate.mirror;
      mode = gate.mode;
      waiting = gate.pending;
      repositories = const <String>[];
      return;
    }
    final answers = await Future.wait(<Future<(String, GateState?, String?)>>[
      for (final name in names) _gateIn(backend, file, name),
    ]);
    if (round != _round) return;
    final read = <(String, GateState)>[
      for (final (name, gate, _) in answers)
        if (gate != null) (name, gate),
    ];
    unread = <({String name, String words})>[
      for (final (name, _, why) in answers)
        if (why != null) (name: name, words: why),
    ];
    // Mirror and mode as the project's own repository answers them, or the first that did.
    mirror = read.isEmpty ? '' : read.first.$2.mirror;
    mode = read.isEmpty ? '' : read.first.$2.mode;
    waiting = <PendingPush>[
      for (final (name, gate) in read)
        for (final push in gate.pending) push.inRepository(name),
    ];
    repositories = <String>[for (final (name, _) in read) name];
    if (unread.isNotEmpty) {
      problem = _unreadSaid = <String>[for (final each in unread) '${each.name} could not be read: ${each.words}']
          .join(' ');
    }
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

  /// The machine the shown gate was read from, and which read is the newest: an answer to an older one is for
  /// a project or machine no longer shown, and is dropped.
  FleetBackend? _from;
  int _round = 0;

  Future<void> _asking(Future<void> Function() ask, {int? round}) async {
    final mine = round ?? _round;
    busy = true;
    problem = null;
    notifyListeners();
    try {
      await ask();
    } on VarlinkException catch (refusal) {
      // A named refusal is an answer: BranchRequired and ProjectRequired both land here, and both
      // are things somebody did rather than things that broke.
      if (mine == _round) problem = _wordsFor(refusal);
    } on VarlinkDisconnected catch (ex) {
      if (mine == _round) problem = 'Lost contact with the machine: ${ex.message}';
    } on FeatureNotSupported catch (ex) {
      if (mine == _round) problem = '$ex';
    } finally {
      if (mine == _round) {
        busy = false;
        notifyListeners();
      }
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
    // The numbers are the machine's: what the answer would take, and what one answer may.
    'ReviewTooLarge' =>
      'The review of ${refusal.parameters['name'] ?? 'this push'} does not fit one answer: it would take '
          '${_bytes(refusal.parameters['bytes'])}, and one answer takes at most ${_bytes(refusal.parameters['limit'])}. '
          '${_command(refusal.parameters['command'])}',
    'InvalidParameter' =>
      'The machine refused what it was asked'
          '${refusal.parameters['parameter'] is String ? ', naming ${refusal.parameters['parameter']}' : ''}. '
          'It is not asked again for this review.',
    _ => 'Refused: ${refusal.simpleName}.',
  };

  static String _bytes(Object? bytes) => bytes is int ? HandingIn.inWords(bytes) : 'a size it did not say';

  static String _command(Object? command) => command is List && command.isNotEmpty && command.every((e) => e is String)
      ? 'On the machine, ${command.cast<String>().map(quoteForAShell).join(' ')} prints the whole review.'
      : 'The machine named no command that prints it.';
}

/// One `Review` answer, and what every page of it is asked with: a page is never asked for a review other
/// than the one shown.
@immutable
class _ReviewRead {
  const _ReviewRead({
    required this.project,
    required this.name,
    required this.repository,
    required this.commit,
    required this.base,
    required this.ignoreLineEndings,
    required this.files,
    required this.commits,
    required this.looks,
    required this.afterAMove,
  });

  final String project;
  final String name;
  final String? repository;

  /// The commit the review is of; null where the machine did not name it, and then no page can be asked.
  final String? commit;

  /// What the pages are read against, as `Review.paged.base` named it.
  final String base;
  final bool ignoreLineEndings;

  /// How many files and commits the machine counted; null where it gave them whole.
  final int? files;
  final int? commits;

  /// Which look read it.
  final int looks;

  /// Whether it was read again because the push moved: a page that says it moved once more is then said,
  /// not read again.
  final bool afterAMove;
}

/// A waiting push's review summary as far as it is read: being read, read, or why it is not there.
@immutable
final class ChecksRead {
  /// While it is read.
  const ChecksRead.reading() : summary = null, words = null;

  /// Read: the daemon's counts.
  const ChecksRead.read(ReviewSummary this.summary) : words = null;

  /// Not read, and why, in words.
  const ChecksRead.unread(String this.words) : summary = null;

  /// Said where the machine is older than the summary: nothing was counted, so nothing reads as zero.
  static const notReported = 'Checks: not reported';

  /// What the daemon answered; null while read and where it is not there.
  final ReviewSummary? summary;

  /// Why it is not there; null while read and once read.
  final String? words;

  /// Whether it is being read now.
  bool get reading => summary == null && words == null;

  /// The open findings and threads, in words: `2 open findings · 1 open thread`.
  static String countsWords(ReviewSummary summary) =>
      '${_count(summary.openFindings, 'open finding')} · ${_count(summary.openThreads, 'open thread')}';

  /// One run, in words: its name, its completeness as the daemon said it, and its findings. Only a complete run with
  /// none reads "no findings"; every other run's zero is "0 findings so far".
  static String runWords(ReviewRun run) {
    if (!run.complete) {
      final word = run.completeness.trim().isEmpty ? 'no word given' : run.completeness;
      return '${run.name}: $word · ${_count(run.findings, 'finding')} so far';
    }
    return '${run.name}: complete · ${run.findings == 0 ? 'no findings' : _count(run.findings, 'finding')}';
  }

  /// Said where no check ran: never clean.
  static const noRun = 'No check ran on this push.';

  /// The line a waiting push's row carries: its counts, and how many checks are not complete or that none ran.
  static String lineWords(ReviewSummary summary) => <String>[
    countsWords(summary),
    if (summary.runs.isEmpty)
      'no check ran'
    else if (summary.notComplete > 0)
      '${_count(summary.notComplete, 'check')} not complete',
  ].join(' · ');

  static String _count(int count, String what) => '$count $what${count == 1 ? '' : 's'}';
}

/// The command that reads and answers a waiting push's findings and threads on this computer, each value quoted for a
/// POSIX shell where it is not a plain word: the interface itself never reads or writes them.
String reviewCommentsCommand({required String name, required String project, String? repository}) => <String>[
  'porelo',
  'gate',
  'comments',
  quoteForAShell(name),
  '--project',
  quoteForAShell(project),
  if (repository != null && repository.isNotEmpty) ...<String>['--repository', quoteForAShell(repository)],
].join(' ');
