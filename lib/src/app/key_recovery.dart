import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:porelo_frontend/client.dart' show RegistryCard, RegistryFiled, RegistryHost, RegistryOwner;
import 'package:porelo_host/porelo_host.dart' show HostFileWriter;

import 'access_checkout.dart' show privateDirectory;
import 'host_access.dart' show HostAdminIdentity;
import 'host_access_contract.dart' show HostRegistryTransport, checkedRegistryRevision;
import 'identity.dart' show Identity, operationIdPattern;
import 'pty.dart' show TerminalStillRunning, closeBound;
import 'project_access_contract.dart' show ProjectAccessCoreAdapter, ProjectAccessNotAdmin, ProjectAccessView;
import 'quiet_after_dispose.dart';
import 'registry.dart';
import 'run_here.dart';
import 'settings.dart';

/// Which signed list a key replacement changes.
enum RecoveryKind {
  /// A project's access file, changed by a project admin with `project access replace`.
  project,

  /// A host's `hosts/<host>/access.yml`, filed by a host admin.
  hostAccess,

  /// A host's admin entry in `owners.yml`, filed by a registry owner.
  hostAdmin,

  /// A registry owner's entry in `owners.yml`, filed by another owner.
  owner,
}

/// The one list a replacement may change, and the backup key that may stand in for its single admin.
@immutable
class RecoveryScope {
  const RecoveryScope._(this.kind, this.name);

  /// The access file of [project].
  const RecoveryScope.project(String project) : this._(RecoveryKind.project, project);

  /// The access file of [host] in the registry.
  const RecoveryScope.hostAccess(String host) : this._(RecoveryKind.hostAccess, host);

  /// The admins `owners.yml` names for [host].
  const RecoveryScope.hostAdmin(String host) : this._(RecoveryKind.hostAdmin, host);

  /// The registry's owners in `owners.yml`.
  const RecoveryScope.owner() : this._(RecoveryKind.owner, null);

  /// Which list.
  final RecoveryKind kind;

  /// The project or host, absent for the owners.
  final String? name;

  /// Whether Core commits this change in the registry checkout and leaves pushing it to this interface.
  bool get inRegistry => kind != RecoveryKind.project;

  /// Core's `identity backup-key` scope flags, or null where no backup key is kept for the list.
  List<String>? get backupFlags => switch (kind) {
    RecoveryKind.project => ['--project', name!],
    RecoveryKind.hostAdmin => ['--host', name!],
    RecoveryKind.owner => ['--registry'],
    RecoveryKind.hostAccess => null,
  };

  /// The scope `kind` Core's backup-key answer names.
  String? get backupKind => switch (kind) {
    RecoveryKind.project => 'project',
    RecoveryKind.hostAdmin => 'host',
    RecoveryKind.owner => 'registry',
    RecoveryKind.hostAccess => null,
  };

  /// The list in a person's words.
  String get words => switch (kind) {
    RecoveryKind.project => 'the access file of project $name',
    RecoveryKind.hostAccess => 'hosts/$name/access.yml',
    RecoveryKind.hostAdmin => 'owners.yml, the host admins of $name',
    RecoveryKind.owner => 'owners.yml, the registry owners',
  };

  /// Who may replace a key in this list.
  String get whoWords => switch (kind) {
    RecoveryKind.project => 'a project admin',
    RecoveryKind.hostAccess => 'a host admin of $name',
    RecoveryKind.hostAdmin || RecoveryKind.owner => 'a registry owner',
  };

  /// Where a pending request for this list is kept.
  String get receiptKey => name == null ? kind.name : '${kind.name}/$name';

  /// The scope's public record.
  Map<String, Object?> get stored => {'kind': kind.name, 'name': name};

  /// Reads a kept scope, refusing anything else.
  factory RecoveryScope.read(Object? value) {
    if (value is! Map) throw const FormatException('Invalid kept scope.');
    final kind = RecoveryKind.values.where((kind) => kind.name == value['kind']).firstOrNull;
    final name = value['name'];
    if (kind == null || (kind == RecoveryKind.owner) != (name == null) || name != null && name is! String) {
      throw const FormatException('Invalid kept scope.');
    }
    return RecoveryScope._(kind, name as String?);
  }

  @override
  bool operator ==(Object other) => other is RecoveryScope && other.kind == kind && other.name == name;

  @override
  int get hashCode => Object.hash(kind, name);
}

/// The list as read now: its persons and their keys, the commit in force and where each person has a host account.
@immutable
class RecoverySituation {
  /// Keeps the read; [people] maps each login to the fingerprint the list names for it now.
  RecoverySituation({
    required this.scope,
    required Map<String, String> people,
    required List<RegistryCard> cards,
    required this.base,
    required this.actor,
    required Map<String, List<String>> hosts,
    required this.checkout,
    this.soleAdmin,
    this.backupRegistered = false,
    this.resumeOnly = false,
    this.madeHere,
    this.madeHereReplaced,
    String? backupBase,
    this.backupUsed,
    Map<String, String> cardTexts = const {},
  }) : backupBase = backupBase ?? (scope.kind == RecoveryKind.project ? null : base),
       cardTexts = Map.unmodifiable(cardTexts),
       people = Map.unmodifiable(people),
       cards = List.unmodifiable(cards),
       hosts = Map.unmodifiable(hosts);

  /// The list.
  final RecoveryScope scope;

  /// Each person's login and the fingerprint the list names for them now.
  final Map<String, String> people;

  /// The registry's person cards, refused ones included so they are never offered.
  final List<RegistryCard> cards;

  /// The commit in force, which the change is made against.
  final String? base;

  /// The person at this computer, as Core proved them; absent before their identity is read.
  final HostAdminIdentity? actor;

  /// The hosts each login has an account on, where a revoked key must be locked.
  final Map<String, List<String>> hosts;

  /// The registry checkout whose `people/LOGIN.card` is the new card Core takes, absent when none is here.
  final String? checkout;

  /// The login of the list's single admin or owner, absent when it has several or none.
  final String? soleAdmin;

  /// Whether a backup key is filed for [soleAdmin].
  final bool backupRegistered;

  /// Whether this is only a kept request's own record, not a clean read: it finishes that request and starts nothing.
  final bool resumeOnly;

  /// A commit made here on [base] that this read does not show yet, or null: its people and roles are older than it,
  /// so no replacement is reviewed on it, while a backup key, which touches only its own entry, is made on it. For a
  /// project, only one in its access file: what its backup key makes in its own repository changes no access.
  final String? madeHere;

  /// The login whose key a replacement in [madeHere] or before it replaced, or null when that is no replacement.
  final String? madeHereReplaced;

  /// The commit a backup key for this list is made or used on, which Core compares with the head it changes: for a
  /// project its own repository's, where `project.yml` names the backup key, never the access repository's; the
  /// list's [base] otherwise. Null when it is not read.
  final String? backupBase;

  /// For a project, the login whose key its backup key replaced here in the project's own repository, while the access
  /// file still names the key it replaced; null otherwise. That replacement is done: the backup key stays, and the
  /// project file no longer names the old key, so neither its use nor a new backup key is offered for that login.
  final String? backupUsed;

  /// The exact text of each new card the checkout held when this was read, by login: what a review of it reviews.
  final Map<String, String> cardTexts;

  /// The new card waiting for [login]: another key than the list names, only one Core trusts.
  ///
  /// A first-seen card, or a state this interface does not know, is shown and never offered.
  RegistryCard? newCard(String login) {
    final old = people[login];
    final card = cards.where((card) => card.login == login).firstOrNull;
    if (old == null || card == null || !card.trusted || card.fingerprint.isEmpty || card.fingerprint == old) {
      return null;
    }
    return card;
  }

  /// Why the backup key may not replace [login]'s key here, or null when it may be offered.
  String? whyNoBackup(String login) {
    if (scope.backupFlags == null) return 'No backup key is kept for ${scope.words}.';
    if (soleAdmin == null) return 'The backup key is only for a list with a single admin or owner.';
    if (soleAdmin != login) return 'The backup key replaces only its own admin’s key, $soleAdmin’s.';
    if (actor?.login != login) return 'Only $login uses their backup key, on their own computer.';
    if (!backupRegistered) return 'No backup key is filed for $login.';
    if (backupUsed == login) {
      return 'The backup key replaced $login’s key in the project file already; the project’s host takes it at its '
          'next sync.';
    }
    return null;
  }
}

/// The replacement a person reviewed, carried unchanged to Core.
@immutable
class RecoveryReview {
  /// Keeps every value the person saw before confirming.
  const RecoveryReview({
    required this.scope,
    required this.login,
    required this.oldFingerprint,
    required this.newFingerprint,
    required this.newKey,
    required this.card,
    required this.base,
    required this.hosts,
    this.cardText,
    this.stolen = false,
    this.backup = false,
  });

  /// The list changed.
  final RecoveryScope scope;

  /// The person, whose login stays.
  final String login;

  /// The key that goes under `revoked`.
  final String oldFingerprint;

  /// The key that comes in.
  final String newFingerprint;

  /// The new public key, `ssh-ed25519 AAAA...`.
  final String newKey;

  /// The new card's file in the registry checkout: a project replacement and a backup key's use read it once after the
  /// check and hand Core a private copy of it.
  final String card;

  /// The commit in force the change is made against.
  final String base;

  /// Every host the person has an account on.
  final List<String> hosts;

  /// The new card's exact text as the review read it: the only card a project replacement or a backup key's use hands
  /// Core. Absent only in a review kept before it was read.
  final String? cardText;

  /// Whether the old key is in another's hands.
  final bool stolen;

  /// Whether the backup key signs it.
  final bool backup;

  /// The review's public record; it names no backup file.
  Map<String, Object?> get stored => {
    'scope': scope.stored,
    'login': login,
    'old': oldFingerprint,
    'new': newFingerprint,
    'key': newKey,
    'card': card,
    'base': base,
    'hosts': hosts,
    'cardText': cardText,
    'stolen': stolen,
    'backup': backup,
  };

  /// Reads a kept review field by field.
  factory RecoveryReview.read(Object? value) {
    if (value is! Map) throw const FormatException('Invalid kept review.');
    String text(String field) {
      final found = value[field];
      if (found is! String || found.isEmpty) throw FormatException('Invalid kept $field.');
      return found;
    }

    final hosts = value['hosts'];
    final stolen = value['stolen'];
    final backup = value['backup'];
    final cardText = value['cardText'];
    if (hosts is! List ||
        hosts.any((host) => host is! String) ||
        stolen is! bool ||
        backup is! bool ||
        cardText != null && (cardText is! String || cardText.isEmpty)) {
      throw const FormatException('Invalid kept review.');
    }
    return RecoveryReview(
      scope: RecoveryScope.read(value['scope']),
      login: text('login'),
      oldFingerprint: text('old'),
      newFingerprint: text('new'),
      newKey: text('key'),
      card: text('card'),
      base: checkedRegistryRevision(text('base')),
      hosts: List.unmodifiable(hosts.cast<String>()),
      cardText: cardText as String?,
      stolen: stolen,
      backup: backup,
    );
  }

  /// Whether [text] is the card this review read, its exact text; never for a review kept before it read one, as a
  /// rotated card of the same key names the same key and is another card.
  bool isReviewedCard(String text) => cardText != null && text == cardText;
}

/// What a replacement made: the signed commit, and whether it reached the shared repository.
@immutable
class RecoveryFiled {
  /// Keeps Core's revision.
  const RecoveryFiled({required this.revision, required this.published});

  /// The signed commit.
  final String revision;

  /// Whether it is pushed.
  final bool published;
}

/// What one host confirmed of a replacement.
@immutable
sealed class HostLock {
  const HostLock(this.host);

  /// The host.
  final String host;

  /// Whether the host confirmed its part.
  bool get confirmed => false;
}

/// For a stolen key: the host confirmed the person locked at the revoking commit.
class HostLocked extends HostLock {
  /// Names the host.
  const HostLocked(super.host);

  @override
  bool get confirmed => true;
}

/// For a lost key: the host confirmed it applied the replacing commit.
class HostReplaced extends HostLock {
  /// Names the host.
  const HostReplaced(super.host);

  @override
  bool get confirmed => true;
}

/// The host has not confirmed yet; the change reaches it at its next connect.
class HostLockPending extends HostLock {
  /// Names the host and why it is not confirmed.
  const HostLockPending(super.host, this.why);

  /// Why, in words.
  final String why;
}

/// The host refused the revoking commit.
class HostLockRefused extends HostLock {
  /// Names the host and its refusal.
  const HostLockRefused(super.host, this.why);

  /// The host's words.
  final String why;
}

/// Brings a replacing commit to a host and answers what that host confirms.
abstract interface class RevocationHosts {
  /// Delivers [revision] of [review] to [host] and answers what the host confirms of it.
  Future<HostLock> deliver(RecoveryReview review, String host, String revision);
}

/// Where pending requests, and the newest commit made here in a project, are kept across dialogs and restarts; never a
/// backup file's place or content.
abstract interface class RecoveryReceipts {
  /// The request kept under [key], or null.
  Map<String, Object?>? read(String key);

  /// Keeps [receipt] under [key].
  Future<void> keep(String key, Map<String, Object?> receipt);

  /// Forgets what is kept under [key].
  Future<void> forget(String key);

  /// Every key a request is kept under now.
  List<String> get keys;
}

/// Core's boundary for a replacement: who may, and the one signed change.
abstract interface class KeyRecoveryCore {
  /// Why the person here may not replace a key in [scope], naming who may; null when they may.
  ///
  /// With [backup], the person's own backup key signs, so only their identity is asked.
  Future<RegistryRefusal?> refusal(RecoveryScope scope, {bool backup = false});

  /// The file a replacement of [review] hands Core, made once before its first attempt and kept with its request: a
  /// registry list's new text, or the new card a project's replacement or a backup key's use hands Core, read once
  /// from the checkout and the exact text reviewed. [holder] is the run's hold on the registry checkout, if it has one.
  Future<String?> fileFor(RecoveryReview review, {Object? holder});

  /// Refuses [review] when its list moved past the reviewed base, or its new card is no longer the reviewed key, or the
  /// registry checkout is read or held by another run now: a change filed then would be made against another state
  /// than the person saw. [holder] is the run's own hold on the registry checkout, if it has one.
  Future<void> checkReviewed(RecoveryReview review, {Object? holder});

  /// Signs [review] under [id] on its base and answers the commit; the same id on the same base answers the same one.
  ///
  /// Core is handed [content], made by [fileFor]; [again] tries a request whose earlier answer was lost, so its own
  /// commit may wait unpushed in the registry checkout. [holder] is the run's hold on the registry checkout.
  Future<RecoveryFiled> replace(
    RecoveryReview review,
    String id, {
    String? content,
    bool again = false,
    Object? holder,
  });

  /// Readies the registry checkout before Core commits a change there in a terminal, for the run [holder].
  Future<void> prepare(RecoveryScope scope, {Object? holder});

  /// Pushes [revision], which Core committed in the registry checkout under request [id] on [base], or on the commit it
  /// read last, and did not push, for the run [holder]; any commit but the request's own is refused.
  Future<void> publish(
    RecoveryScope scope,
    String revision, {
    required String base,
    required String id,
    Object? holder,
  });

  /// Takes the registry checkout for the run whose token [holder] is, made for that run alone, until [release] with
  /// the same token, so no registry read or filing runs beside it; throws a [RegistryRefusal] with words while one
  /// runs or another run holds it.
  void hold(Object holder);

  /// Lets go of the checkout [holder] took; a token that does not hold it lets go of nothing.
  void release(Object holder);

  /// Writes [content], the reviewed card of [login], into a private file of its own that Core is handed, and answers
  /// its path.
  Future<String> copyCard(String login, String content);

  /// Removes the copy [file] made by [copyCard]; never throws, as Core's answer counts more than the copy.
  Future<void> dropCard(String file);
}

/// Core refused or could not make a replacement; carries its exit code and typed reason.
class RecoveryRefused extends RegistryRefusal {
  /// Keeps the code, Core's reason and its words.
  const RecoveryRefused(super.words, {required this.code, this.reason, super.whoMay});

  /// Core's exit code; [answerRefused] for an answer Core gave that this interface refused, 0 for a change refused
  /// before Core ran.
  final int code;

  /// Core's fixed reason, when it named one.
  final String? reason;

  /// Whether nothing was made under the request, so the next attempt is a new decision.
  bool get nothingMade => const {64, 65, 66}.contains(code);

  /// Whether Core's answer proves no commit exists under the request, so even an uncertain one may be dropped.
  bool get provesNoneMade => nothingMade && _provesNoneMade(reason);
}

/// The code of an answer Core gave after it ran that this interface refused: never read as nothing made, as Core's
/// commit may stand behind it.
const answerRefused = 70;

/// Whether Core's typed [reason] proves no commit exists under a kept `--id`: Core makes nothing for the list in this
/// release, or the list moved past the request's base, where the same id would have been answered as made.
bool _provesNoneMade(String? reason) => reason == 'not-in-this-release' || reason == 'base-moved';

/// Whether a terminal made nothing: its program never [started], or Core's own [code] says wrong use, refused or
/// unreadable. A program that started and was put away, killed or ended unseen may have made anything.
bool _terminalMadeNothing({required bool started, required int? code}) =>
    !started || code != null && const {64, 65, 66}.contains(code);

/// What a refused change says when Core read the list at another state than the review showed.
const reviewMoved = 'The registry changed since the review; review again.';

/// The words of a typed backup-key refusal Core gives, or of its exit code; none when its end was not seen.
String backupKeyWords(int? code, String? reason, String? words, {bool started = true}) {
  if (!started) return 'The terminal did not start Core. Nothing changed.';
  final said = words != null && words.trim().isNotEmpty ? ' ${words.trim()}' : '';
  return switch (reason) {
    'not-sole' => 'You are not the single admin or owner here; another admin replaces the key.$said',
    'backup-exists' => 'A backup key is filed for you already.$said',
    'not-signer' => 'Your SSH agent holds no key that may file it.$said',
    'file-exists' => 'That file exists already; choose a new one.$said',
    'no-terminal' => 'No terminal was there to ask the passphrase on.$said',
    'wrong-passphrase' => 'The backup file did not open with that passphrase. Nothing changed.$said',
    'not-the-backup' => 'This is not the backup key filed for this list. Nothing changed.$said',
    'backup-only-own' => 'The backup key may only replace its own admin’s entry. Nothing changed.$said',
    'card-login' => 'The new card is of another login, or does not verify. Nothing changed.$said',
    'revoked' => 'The backup key, or the new card’s key, is revoked. Nothing changed.$said',
    'base-moved' => 'The list changed since it was read. Read it again and review again.$said',
    'not-in-this-release' => 'Porelo on this computer does not do this for this list yet. Nothing changed.$said',
    final String other => 'Core refused it ($other).$said',
    null => switch (code) {
      null || -1 =>
        'The terminal was put away before Core answered, or its end could not be read, so Core may have made the '
            'commit already and its request is kept: Retry runs the backup key again under it, which answers that '
            'commit; nothing is filed anew.',
      64 => 'Core did not take this call. Nothing changed.',
      66 => 'The backup file, the project or the registry checkout could not be read. Nothing changed.',
      _ =>
        'Core may have made the commit already. Retry runs the backup key again under the same request, '
            'which answers that commit; nothing is filed anew.',
    },
  };
}

/// What runs Core for key recovery now, per place requests are kept, so every dialog over that place sees it and
/// rebuilds when it ends: a dialog opened again meets an attempt still running.
class RecoveryRuns extends ChangeNotifier {
  RecoveryRuns._();

  static final _of = Expando<RecoveryRuns>('Core running for key recovery');

  /// The runs over [receipts], shared by every replacement and backup key kept there.
  static RecoveryRuns of(RecoveryReceipts receipts) => _of[receipts] ??= RecoveryRuns._();

  final _scopes = <String, RecoveryScope>{};

  /// Whether something runs under the request kept as [key].
  bool runs(String key) => _scopes.containsKey(key);

  /// Every request key something runs under now.
  Iterable<String> get keys => _scopes.keys;

  /// Why a change of [scope] under [key] may not start now, or null when it may: one run per request, and one in the
  /// registry checkout, where a second change would meet the first's commit.
  String? whyNotStart(String key, RecoveryScope scope) {
    if (runs(key)) return 'Core still runs for ${scope.words}; wait until it has ended.';
    if (scope.inRegistry && _scopes.values.any((each) => each.inRegistry)) {
      return 'Another change runs in the registry checkout; wait until it has ended.';
    }
    return null;
  }

  /// Counts [key] as running for [scope], until [end].
  void start(String key, RecoveryScope scope) {
    _scopes[key] = scope;
    notifyListeners();
  }

  /// Counts [key] as running no longer.
  void end(String key) {
    if (_scopes.remove(key) != null) notifyListeners();
  }

  final _outlived = <String, ({TerminalStillRunning still, Completer<void> byHand})>{};

  /// Whether the terminal of the request kept as [key] was put away while its program still runs.
  bool outlived(String key) => _outlived.containsKey(key);

  /// Waits, for the request kept as [key], on [still], a terminal put away while its program still runs: until that
  /// program ended, or was ended by [endOutlived]. Meanwhile it may still write, so whatever its run holds stays held.
  Future<void> outlive(String key, TerminalStillRunning still) async {
    final byHand = Completer<void>();
    _outlived[key] = (still: still, byHand: byHand);
    notifyListeners();
    try {
      await Future.any([still.ended.then<void>((_) {}, onError: (Object _) {}), byHand.future]);
    } finally {
      if (identical(_outlived[key]?.byHand, byHand)) _outlived.remove(key);
      notifyListeners();
    }
  }

  /// Ends by force the program the request kept as [key] left running in a put-away terminal; once ended it writes
  /// nothing more, so its run lets go of what it held, after its end, or the close's bound, has passed.
  Future<void> endOutlived(String key) async {
    final outlived = _outlived[key];
    final end = outlived?.still.end;
    if (outlived == null || end == null) return;
    try {
      await end();
    } on Object {
      // It could not be ended: its run still waits on its own end.
      return;
    }
    try {
      await outlived.still.ended.timeout(closeBound);
    } on Object {
      // Ended by force: what it was still doing is cut off.
    }
    if (!outlived.byHand.isCompleted) outlived.byHand.complete();
  }
}

/// One key replacement in one list, from review to every host's confirmation.
///
/// **It signs once**: a request ID and base are kept from the moment it starts, across dialogs and restarts; a lost
/// answer is retried under them, which Core answers with the same commit, and a host that confirmed is never asked
/// again.
class KeyRecovery extends ChangeNotifier with QuietAfterDispose {
  /// Constructor taking the list as read now, Core's, the hosts' and the kept requests' boundaries.
  ///
  /// A request kept for this list is resumed as it was left.
  KeyRecovery({
    required this.situation,
    required this.core,
    required this.hosts,
    required this.receipts,
    Random? random,
  }) : _random = random ?? Random.secure() {
    _resume();
    _runs.addListener(_runsChanged);
  }

  late final RecoveryRuns _runs = RecoveryRuns.of(receipts);

  void _runsChanged() => notifyListeners();

  @override
  void dispose() {
    _runs.removeListener(_runsChanged);
    super.dispose();
  }

  /// The list as read when the dialog opened.
  final RecoverySituation situation;

  /// Core's boundary.
  final KeyRecoveryCore core;

  /// The hosts' boundary.
  final RevocationHosts hosts;

  /// Where the pending request is kept.
  final RecoveryReceipts receipts;

  final Random _random;

  /// The replacement awaiting confirmation, or being made.
  RecoveryReview? review;

  /// The request ID under which Core signs, kept until Core answered.
  String? requestId;

  /// The signed commit, once Core answered it.
  RecoveryFiled? filed;

  /// Whether a commit may exist already though its answer was not read, so no later attempt drops the request.
  bool uncertain = false;

  /// What each host confirmed.
  final Map<String, HostLock> locks = {};

  /// What went wrong last, in words.
  String? problem;

  /// Whether a call is running.
  bool busy = false;

  /// Whether Core runs for this request now, here or in a dialog opened before: the backup key's terminal not read
  /// back, or a filing.
  bool get backupRunning => _runs.runs(_key);

  // Whether an attempt before the running one ended uncertain: what a proven-nothing-made end restores.
  bool _earlier = false;

  String get _key => situation.scope.receiptKey;

  /// Whether the replacement started: a request is kept or a commit made.
  bool get started => requestId != null || filed != null;

  /// Whether the commit is pushed and every host confirmed it.
  bool get allConfirmed =>
      filed?.published == true && review != null && review!.hosts.every((host) => locks[host]?.confirmed ?? false);

  /// Whether the replacement is pushed, so a new backup and the person's vault recreation are offered.
  bool get replaced => filed?.published == true;

  /// Whether something started is unfinished, so Retry is offered; a pushed project commit leaves nothing to retry, as
  /// its host takes it at its next sync.
  bool get unfinished => started && !allConfirmed && !(replaced && situation.scope.kind == RecoveryKind.project);

  /// Whether a kept request may be dropped on the person's word: one whose answer was lost, a made commit owed its
  /// push, or a pushed registry commit some host has not confirmed.
  bool get forgettable =>
      requestId != null ||
      filed != null && (!filed!.published || situation.scope.inRegistry && review != null && !allConfirmed);

  void _resume() {
    final kept = receipts.read(_key);
    if (kept == null) return;
    try {
      final reviewed = RecoveryReview.read(kept['review']);
      final id = kept['id'];
      final revision = kept['revision'];
      final published = kept['published'];
      final confirmed = kept['confirmed'];
      final keptUncertain = kept['uncertain'];
      final content = kept['content'];
      if (reviewed.scope != situation.scope ||
          content != null && content is! String ||
          id is! String ||
          !operationIdPattern.hasMatch(id) ||
          published is! bool ||
          keptUncertain is! bool ||
          confirmed is! Map ||
          revision != null && revision is! String ||
          published && revision == null) {
        throw const FormatException('Invalid kept replacement.');
      }
      review = reviewed;
      requestId = revision == null ? id : null;
      uncertain = keptUncertain;
      _content = content as String?;
      if (revision != null) {
        filed = RecoveryFiled(revision: checkedRegistryRevision(revision as String), published: published);
      }
      for (final host in reviewed.hosts) {
        locks[host] = switch (confirmed[host]) {
          'locked' => HostLocked(host),
          'replaced' => HostReplaced(host),
          _ => HostLockPending(host, 'Not on the host yet.'),
        };
      }
      _keptId = id;
    } on FormatException {
      problem = 'A kept replacement for ${situation.scope.words} could not be read. Nothing is assumed from it.';
    }
  }

  // The request ID stays with a made commit too, so its record keeps naming it.
  String? _keptId;

  // The registry file the request hands Core: a retry hands the same, as the checkout may hold it committed already.
  String? _content;

  Future<void> _keep() {
    final reviewed = review;
    final id = requestId ?? _keptId;
    if (reviewed == null || id == null) return Future.value();
    _keptId = id;
    return receipts.keep(_key, {
      'review': reviewed.stored,
      'id': id,
      'revision': filed?.revision,
      'published': filed?.published ?? false,
      'uncertain': uncertain,
      'content': _content,
      'confirmed': {
        for (final MapEntry(:key, :value) in locks.entries)
          if (value is HostLocked) key: 'locked' else if (value is HostReplaced) key: 'replaced',
      },
    });
  }

  Future<void> _forget() async {
    _keptId = null;
    await receipts.forget(_key);
  }

  /// Drops the request Core's answer proved made nothing; a list known only from that request starts nothing anew.
  Future<void> _drop() async {
    requestId = null;
    _content = null;
    if (situation.resumeOnly) {
      review = null;
      locks.clear();
    }
    await _forget();
  }

  /// Why [login]'s key cannot be reviewed for replacement now, or null when it can.
  String? whyNotReview(String login, {bool backup = false}) {
    if (busy) return 'Still working.';
    if (started) return 'A replacement is started here; retry it.';
    if (situation.resumeOnly) return refreshBeforeReplacing;
    if (situation.madeHere != null) return refreshProjectBeforeReplacing;
    if (!situation.people.containsKey(login)) return '$login is not in ${situation.scope.words}.';
    if (situation.base == null) return 'The commit in force is not read. Read ${situation.scope.words} again.';
    if (backup && situation.backupBase == null) {
      return 'The project’s own commit is not read. Read ${situation.scope.words} again.';
    }
    if (situation.checkout == null) return 'No registry checkout holding the new card is on this computer.';
    if (situation.newCard(login) == null) {
      return 'No new key of $login that Core trusts waits in the registry. They make one with “I lost my key” under '
          'My key and card.';
    }
    if (situation.cardTexts[login] == null) {
      return 'The new card of $login could not be read from the registry checkout. Refresh the registry and review '
          'again.';
    }
    if (backup) return situation.whyNoBackup(login);
    return null;
  }

  /// Shows the replacement of [login]'s key by [card] for review; nothing is called.
  void reviewFor(String login, {RegistryCard? card, bool stolen = false, bool backup = false}) {
    problem = null;
    final reason = whyNotReview(login, backup: backup);
    final waiting = situation.newCard(login);
    final chosen = card ?? waiting;
    if (reason != null || chosen == null || waiting == null) {
      problem = reason ?? 'No new key of $login waits.';
      notifyListeners();
      return;
    }
    if (chosen.login != login) {
      problem = 'The new card is of ${chosen.login}, not $login: a replacement keeps the login.';
    } else if (!chosen.trusted) {
      problem = 'Core does not trust the new card of $login (${chosen.state}).';
    } else if (chosen.fingerprint != waiting.fingerprint) {
      problem = 'That card is not the one the registry holds for $login.';
    }
    if (problem != null) {
      notifyListeners();
      return;
    }
    review = RecoveryReview(
      scope: situation.scope,
      login: login,
      oldFingerprint: situation.people[login]!,
      newFingerprint: chosen.fingerprint,
      newKey: chosen.key,
      card: path.join(situation.checkout!, 'people', '$login.card'),
      // The backup key changes what its own commit names, a project's in its own repository.
      base: backup ? situation.backupBase! : situation.base!,
      hosts: List.unmodifiable(situation.hosts[login] ?? const <String>[]),
      cardText: situation.cardTexts[login],
      stolen: stolen,
      backup: backup,
    );
    notifyListeners();
  }

  /// Drops the review without any call; nothing started can be dropped.
  void cancel() {
    if (started || busy) return;
    review = null;
    problem = null;
    notifyListeners();
  }

  /// Why the reviewed replacement cannot be confirmed now, or null when it can.
  ///
  /// A stolen key's new card cannot be told from one its thief made: its fingerprint is confirmed in person.
  String? whyNotConfirm({bool toldInPerson = false}) {
    final reviewed = review;
    if (busy) return 'Still working.';
    if (reviewed == null) return 'Review the replacement first.';
    if (started) return 'It is started; retry it.';
    if (situation.resumeOnly) return refreshBeforeReplacing;
    if (_runs.whyNotStart(_key, reviewed.scope) case final why?) return why;
    if (reviewed.stolen && !toldInPerson) {
      return 'For a stolen key, confirm that the person told you the new fingerprint themselves.';
    }
    if (reviewed.backup) return situation.whyNoBackup(reviewed.login);
    return null;
  }

  /// Signs the reviewed replacement once with the agent's key, then brings it to every host.
  Future<void> confirm({bool toldInPerson = false}) async {
    if (whyNotConfirm(toldInPerson: toldInPerson) != null || review!.backup) return;
    await _working(
      () => _running(() async {
        final refused = await core.refusal(review!.scope);
        if (refused != null) throw refused;
        await _file();
      }),
    );
  }

  /// Runs [work] counted as Core running for this request, which every dialog over the same requests sees, from its
  /// check to the end of its publishing and delivering; a registry list's run holds the registry checkout meanwhile,
  /// where Core commits.
  Future<void> _running(Future<void> Function() work) async {
    _take();
    _runs.start(_key, situation.scope);
    try {
      await work();
    } finally {
      await _letGo();
    }
  }

  // The token this run holds the registry checkout by, made for it alone; null while it holds nothing.
  Object? _hold;

  // The private copy of the reviewed card a backup key's terminal hands Core, until its program ended.
  String? _cardCopy;

  /// Holds the registry checkout for the run that starts now, under a token of its own, where Core commits: a project's
  /// change is made in its own repository and never writes the checkout, so it holds nothing.
  void _take() {
    if (!situation.scope.inRegistry) return;
    final token = Object();
    core.hold(token);
    _hold = token;
  }

  /// Ends the run counted for this request: its card copy removed, and the checkout let go of by its own token alone.
  Future<void> _letGo() async {
    final held = _hold;
    final copy = _cardCopy;
    _hold = null;
    _cardCopy = null;
    _runs.end(_key);
    if (held != null) core.release(held);
    if (copy != null) await core.dropCard(copy);
  }

  /// Why Retry cannot run now, or null when it can.
  String? get whyNotRetry {
    if (busy) return 'Still working.';
    if (!unfinished) return 'Nothing is unfinished.';
    if (retriesInTerminal) return whyNotBackup();
    return _runs.whyNotStart(_key, situation.scope);
  }

  /// Why the kept request cannot be forgotten, or null when it can: one Core may have made a commit under, not read,
  /// or a commit made in the registry checkout whose push does not go through.
  String? get whyNotForget {
    if (busy) return 'Still working.';
    if (backupRunning) return 'Core still runs for this request; wait until it has ended.';
    if (!forgettable) return 'No request whose answer was lost is kept.';
    return null;
  }

  /// Drops the kept request on the person's word; whatever Core committed under it stays, to be checked by hand.
  ///
  /// A made commit is dropped only when [made] names it, as the confirmation the person read did: one owed its push
  /// stays in the registry checkout, to be pushed or dropped there by hand; a pushed one is no longer delivered to the
  /// hosts that have not confirmed it, which are checked by hand.
  Future<void> forget({String? made}) async {
    if (whyNotForget != null || filed != null && filed!.revision != made) return;
    filed = null;
    _content = null;
    requestId = null;
    uncertain = false;
    review = null;
    problem = null;
    locks.clear();
    await _forget();
    notifyListeners();
  }

  /// The kept request whose terminal was put away while Core still runs in it, this replacement's or its list's backup
  /// key making, or null.
  String? get outlivedKey => [
    _key,
    if (situation.scope.backupFlags != null) BackupKeyMaking.keyOf(situation.scope),
  ].where(_runs.outlived).firstOrNull;

  /// Ends by force Core in a terminal put away while it still ran, for [outlivedKey].
  Future<void> endOutlived() async {
    if (outlivedKey case final key?) await _runs.endOutlived(key);
  }

  /// Whether Retry runs the backup key's terminal again, rather than anything this program calls itself.
  bool get retriesInTerminal => review?.backup == true && filed == null;

  /// Retries only what is unfinished: the same request while Core's answer is missing, the push, each host not done.
  ///
  /// A backup-key request is retried only through [startBackup]: nothing here signs with the agent's key for it.
  Future<void> retry() async {
    if (whyNotRetry != null) return;
    if (retriesInTerminal) {
      problem = 'Retry runs the backup key again in its terminal, under the same request.';
      notifyListeners();
      return;
    }
    await _working(
      () => _running(() async {
        if (filed == null) {
          // A registry request whose answer was lost was checked when it was made; its own unpushed commit keeps the
          // registry from reading clean again, which the check needs.
          if (!(uncertain && review!.scope.inRegistry)) {
            final refused = await core.refusal(review!.scope);
            if (refused != null) throw refused;
          }
          await _file();
        } else {
          await _published();
        }
      }),
    );
  }

  Future<void> _file() async {
    final reviewed = review!;
    final earlier = uncertain;
    // Checked before the request, so a list or card that moved since the review starts nothing; a request whose answer
    // was lost files what it filed before, which its own commit may already hold.
    if (!earlier) {
      await core.checkReviewed(reviewed, holder: _hold);
      // Made before the request, so a list that does not hold the reviewed key starts nothing.
      _content = await core.fileFor(reviewed, holder: _hold);
    } else if (_content == null) {
      _keptWithoutFile();
    }
    requestId ??= _newId();
    // Kept as uncertain before Core runs: an attempt whose end is never read may have made the commit.
    uncertain = true;
    await _keep();
    final RecoveryFiled made;
    try {
      made = await core.replace(reviewed, requestId!, content: _content, again: earlier, holder: _hold);
    } on RecoveryRefused catch (refused) {
      if (refused.reason == 'base-moved') await forgetMadeInForce(receipts, reviewed.scope);
      if (!refused.nothingMade) rethrow;
      uncertain = earlier && !refused.provesNoneMade;
      if (!uncertain) {
        await _drop();
        rethrow;
      }
      await _keep();
      // An earlier attempt may have made the commit: only the same request answers it.
      throw RecoveryRefused(
        '${refused.words} $_madeBefore',
        code: refused.code,
        reason: refused.reason,
        whoMay: refused.whoMay,
      );
    }
    filed = made;
    requestId = null;
    uncertain = false;
    _content = null;
    await _keep();
    await _published();
  }

  /// Refuses a request kept before it kept the file it hands Core, whose answer was lost: that file cannot be made
  /// again as it was, so the request is never tried again blind. Forget is the way out; a commit it made already and
  /// recorded is finished by its push, which takes only the request's own commit.
  static Never _keptWithoutFile() => throw const RecoveryRefused(
    'This request was kept without the file it hands Core, so it is not tried again: Forget drops it once you checked '
    'by hand what Core made under it.',
    code: 0,
  );

  Future<void> _published() async {
    final reviewed = review!;
    var made = filed!;
    if (!made.published) {
      await core.publish(reviewed.scope, made.revision, base: reviewed.base, id: _keptId ?? '', holder: _hold);
      made = filed = RecoveryFiled(revision: made.revision, published: true);
      await _keep();
    }
    await keepMadeInForce(
      receipts,
      reviewed.scope,
      base: reviewed.base,
      revision: made.revision,
      replaced: reviewed.login,
      old: reviewed.oldFingerprint,
      projectRepository: reviewed.backup,
    );
    for (final host in reviewed.hosts) {
      locks.putIfAbsent(host, () => HostLockPending(host, 'Not on the host yet.'));
    }
    for (final host in reviewed.hosts) {
      if (locks[host]?.confirmed ?? false) continue;
      HostLock answer;
      try {
        answer = await hosts.deliver(reviewed, host, made.revision);
        // An answer for another host says nothing about this one.
        if (answer.host != host) answer = HostLockPending(host, 'Not on the host yet: it answered for another.');
      } on RegistryRefusal catch (refused) {
        answer = HostLockPending(host, 'Not on the host yet: ${refused.words}');
      } on Exception {
        answer = HostLockPending(host, 'Not on the host yet: it was not reached. It takes it at its next connect.');
      } on Error {
        // A broken answer from one host must not keep the others from theirs.
        answer = HostLockPending(host, 'Not on the host yet: its answer could not be read.');
      }
      locks[host] = answer;
      await _keep();
      notifyListeners();
    }
    // A pushed project commit leaves nothing that could be made twice, and its hosts answer nothing but pending here:
    // their lock is said beside each, and a receipt kept for it would hold the project's replacements for good.
    if (allConfirmed || reviewed.scope.kind == RecoveryKind.project) await _forget();
  }

  /// Why the backup key's terminal cannot be opened now, or null when it can: first after review, or as Retry.
  String? whyNotBackup({bool toldInPerson = false}) {
    final reviewed = review;
    if (busy) return 'Still working.';
    if (reviewed == null || !reviewed.backup) return 'Review the replacement with the backup key first.';
    if (filed != null) return 'It is made.';
    if (_runs.whyNotStart(_key, reviewed.scope) case final why?) return why;
    if (requestId == null) return whyNotConfirm(toldInPerson: toldInPerson);
    return situation.whyNoBackup(reviewed.login);
  }

  /// Readies the backup key's use after review, or its Retry, and answers the command its terminal runs.
  ///
  /// The backup file's path reaches the command alone; it is neither read, kept nor written anywhere here.
  Future<List<String>?> startBackup(String backupFile, {bool toldInPerson = false}) async {
    if (whyNotBackup(toldInPerson: toldInPerson) case final why?) {
      problem = why;
      notifyListeners();
      return null;
    }
    if (backupFile.trim().isEmpty) {
      problem = 'Choose the backup key’s file.';
      notifyListeners();
      return null;
    }
    final reviewed = review!;
    List<String>? command;
    await _working(() async {
      // Held until its terminal's program ended and its answer was read: Core commits there for the registry.
      _take();
      _runs.start(_key, reviewed.scope);
      var started = false;
      try {
        command = await _readyBackup(reviewed, backupFile);
        started = true;
      } finally {
        if (!started) await _letGo();
      }
    });
    return command;
  }

  /// Checks and keeps the backup key's request, and answers the command its terminal runs.
  Future<List<String>> _readyBackup(RecoveryReview reviewed, String backupFile) async {
    final refused = await core.refusal(reviewed.scope, backup: true);
    if (refused != null) throw refused;
    // A first attempt is checked against the list as read now, and keeps the card it read right after; a retry hands
    // Core that same card again, never the checkout's file, which a refresh may have changed meanwhile.
    if (requestId == null) {
      await core.checkReviewed(reviewed, holder: _hold);
      _content = await core.fileFor(reviewed, holder: _hold);
    } else if (_content == null) {
      _keptWithoutFile();
    }
    final card = _content;
    if (card == null || !reviewed.isReviewedCard(card)) throw const RecoveryRefused(reviewMoved, code: 0);
    // A first attempt checks the checkout is clean; a retry may meet the commit Core made already.
    if (reviewed.scope.inRegistry && requestId == null) await core.prepare(reviewed.scope, holder: _hold);
    requestId ??= _newId();
    _earlier = uncertain;
    // Kept as uncertain before the terminal runs Core: an end never read back may have made the commit.
    uncertain = true;
    await _keep();
    final copy = _cardCopy = await core.copyCard(reviewed.login, card);
    return [
      'porelo',
      'identity',
      'backup-key',
      ...reviewed.scope.backupFlags!,
      '--use',
      backupFile,
      '--card',
      copy,
      '--base',
      checkedRegistryRevision(reviewed.base),
      '--id',
      requestId!,
      '--json',
    ];
  }

  /// Takes what the backup key's terminal ended with: whether its program [started], and Core's exit [code], none when
  /// its end was not seen. Publishes and delivers only the exact reviewed replacement.
  Future<void> backupEnded({required int? code, required String lastLine, bool started = true}) async {
    final reviewed = review;
    final id = requestId;
    if (reviewed == null || id == null || !backupRunning) return;
    try {
      await _backupRead(reviewed, id, code: code, lastLine: lastLine, started: started);
    } finally {
      // Counted as running, and holding, until its answer was read, published and delivered.
      await _letGo();
    }
  }

  Future<void> _backupRead(
    RecoveryReview reviewed,
    String id, {
    required int? code,
    required String lastLine,
    required bool started,
  }) async {
    await _working(() async {
      if (_terminalMadeNothing(started: started, code: code)) {
        final typed = Identity.typedRefusal(lastLine);
        final words = backupKeyWords(code, typed?.reason, typed?.words, started: started);
        // The backup key's commit is made in the project's own repository: the access file's record stays.
        if (typed?.reason == 'base-moved') await forgetMadeInForce(receipts, reviewed.scope, projectRepository: true);
        uncertain = _earlier && !_provesNoneMade(typed?.reason);
        if (uncertain) {
          await _keep();
          // An earlier attempt may have made the commit: dropping its request would make a second one.
          throw RecoveryRefused('$words $_madeBefore', code: code ?? -1, reason: typed?.reason);
        }
        await _drop();
        throw RecoveryRefused(words, code: code ?? -1, reason: typed?.reason);
      }
      // From here Core ran and may have made the commit: anything but the exact answer keeps the request uncertain.
      final RecoveryFiled made;
      try {
        if (code != 0) {
          final typed = Identity.typedRefusal(lastLine);
          throw RecoveryRefused(
            backupKeyWords(code, typed?.reason, typed?.words),
            code: code ?? -1,
            reason: typed?.reason,
          );
        }
        made = checkedBackupUse(lastLine, reviewed, id);
      } on RecoveryRefused {
        // Core ran: an answer not read, or not the reviewed one, may stand for a made commit, never published here.
        uncertain = true;
        await _keep();
        rethrow;
      }
      filed = made;
      requestId = null;
      uncertain = false;
      _content = null;
      await _keep();
      await _published();
    });
  }

  /// Keeps the backup key's terminal counted as open after it was put away while Core still ran, [still], until Core
  /// ended or was ended by [endOutlived]; its run holds the registry checkout meanwhile.
  ///
  /// Its answer is never read: the request stays kept as uncertain, for Retry under it or Forget.
  Future<void> backupOutlived(TerminalStillRunning still) async {
    if (!backupRunning) return;
    problem =
        'The terminal was put away while Core still ran in it. Nothing can be retried or forgotten until it ends; '
        'end it here if it does not.';
    notifyListeners();
    await _runs.outlive(_key, still);
    await _letGo();
    problem =
        'Core ended after its terminal was put away; its answer was not read. Retry runs the backup key again under '
        'the same request.';
    notifyListeners();
  }

  Future<void> _working(Future<void> Function() work) async {
    busy = true;
    problem = null;
    notifyListeners();
    try {
      await work();
    } on RecoveryRefused catch (refused) {
      problem = refused.toString();
    } on RegistryRefusal catch (refused) {
      problem = refused.toString();
    } on WorkspaceRefused catch (refused) {
      problem = refused.words;
    } on FormatException {
      problem = 'Core gave an answer this interface cannot read. Nothing is assumed from it; Retry.';
    } on Exception {
      problem = 'Core could not be run. Retry: the same request answers the same commit.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// What a resume-only list answers to anything new.
  static const refreshBeforeReplacing = 'Refresh the registry before replacing a key.';

  /// What a project read older than a commit made here answers to a new replacement.
  static const refreshProjectBeforeReplacing = 'Refresh the project before replacing a key.';

  static const _madeBefore =
      'An earlier attempt may have made the commit already, so its request is kept: Retry runs it again under the '
      'same request.';

  String _newId() => List.generate(16, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

/// Reads `identity backup-key --use`'s answer, refusing one that is not exactly the reviewed replacement.
///
/// Refused before publication or any host sync: an answer for another request, list or key would carry the backup
/// key's authority beyond the one entry it may change. An unreadable answer may still mean a made commit.
RecoveryFiled checkedBackupUse(String lastLine, RecoveryReview reviewed, String id) {
  final Object? decoded;
  try {
    decoded = jsonDecode(lastLine.trim());
  } on FormatException {
    throw RecoveryRefused(backupKeyWords(70, null, null), code: 70);
  }
  if (decoded is! Map<String, dynamic>) throw RecoveryRefused(backupKeyWords(70, null, null), code: 70);
  final scope = decoded['scope'];
  final revision = decoded['revision'];
  final published = decoded['pushed'];
  if (scope is! Map<String, dynamic> || revision is! String || published is! bool) {
    throw RecoveryRefused(backupKeyWords(70, null, null), code: 70);
  }
  String? refusal;
  if (decoded['id'] != id) {
    refusal = 'Core answered another request than this one.';
  } else if (scope['kind'] != reviewed.scope.backupKind || scope['name'] != reviewed.scope.name) {
    refusal = 'Core changed another list than ${reviewed.scope.words}.';
  } else if (decoded['replaced'] != reviewed.oldFingerprint || decoded['by'] != reviewed.newFingerprint) {
    refusal = 'Core replaced another key than the reviewed one.';
  } else if (published == reviewed.scope.inRegistry) {
    refusal = 'Core answered the push the other way round for this list.';
  }
  if (refusal != null) {
    throw RecoveryRefused(
      '$refusal Nothing is ${reviewed.scope.inRegistry ? 'pushed' : 'delivered to a host'}; '
      'the backup key changes only its own entry. Core ran, so its request is kept: Retry asks Core again under it, '
      'or Forget drops it once you checked by hand what it made.',
      code: answerRefused,
    );
  }
  return RecoveryFiled(revision: checkedRegistryRevision(revision), published: published);
}

/// What `identity backup-key --out` made.
@immutable
class BackupKeyMade {
  /// Keeps Core's answer.
  const BackupKeyMade({required this.fingerprint, required this.revision, required this.published, required this.file});

  /// Where Core wrote the backup key's file.
  final String file;

  /// The backup key's fingerprint.
  final String fingerprint;

  /// The commit that files it.
  final String revision;

  /// Whether it is pushed.
  final bool published;
}

/// The command a terminal runs to make a backup key for [scope] into the new file [out], under request [id] on [base].
List<String> backupMakeCommand(RecoveryScope scope, {required String out, required String id, required String base}) {
  final flags = scope.backupFlags;
  if (flags == null) throw FormatException('No backup key is kept for ${scope.words}.');
  if (out.trim().isEmpty) throw const FormatException('Choose where the backup key’s file goes.');
  if (!operationIdPattern.hasMatch(id)) throw const FormatException('Not a request ID.');
  return [
    'porelo',
    'identity',
    'backup-key',
    ...flags,
    '--out',
    out,
    '--id',
    id,
    '--base',
    checkedRegistryRevision(base),
    '--json',
  ];
}

/// Reads what a backup-key making terminal ended with, refusing an answer for another request, list, file or push.
///
/// Without [out], any file is taken: a retry of an uncertain request meets the file an earlier attempt wrote.
BackupKeyMade backupMadeFrom(
  RecoveryScope scope, {
  required int? code,
  required String lastLine,
  required String id,
  required String? out,
}) {
  if (code != 0) {
    final typed = Identity.typedRefusal(lastLine);
    throw RecoveryRefused(backupKeyWords(code, typed?.reason, typed?.words), code: code ?? -1, reason: typed?.reason);
  }
  final Object? answer;
  try {
    answer = jsonDecode(lastLine.trim());
  } on FormatException {
    throw RecoveryRefused(backupKeyWords(70, null, null), code: 70);
  }
  if (answer is! Map<String, dynamic>) throw RecoveryRefused(backupKeyWords(70, null, null), code: 70);
  final answered = answer['scope'];
  final fingerprint = answer['fingerprint'];
  final revision = answer['revision'];
  final published = answer['pushed'];
  final file = answer['file'];
  if (answer['id'] != id ||
      answered is! Map<String, dynamic> ||
      answered['kind'] != scope.backupKind ||
      answered['name'] != scope.name ||
      file is! String ||
      file.isEmpty ||
      out != null && file != out ||
      fingerprint is! String ||
      !fingerprint.startsWith('SHA256:') ||
      revision is! String ||
      published != !scope.inRegistry) {
    throw const RecoveryRefused(
      'Core answered another backup key than the one asked for. Nothing is published.',
      code: answerRefused,
    );
  }
  return BackupKeyMade(
    fingerprint: fingerprint,
    revision: checkedRegistryRevision(revision),
    published: published as bool,
    file: file,
  );
}

/// Where the newest commit made here in a project's access is kept, which a project read before it does not show yet;
/// with [projectRepository], the newest made in the project's own repository by its backup key, kept apart, as the two
/// repositories' commits are read and compared each on its own.
String _inForceKey(RecoveryScope scope, {bool projectRepository = false}) =>
    projectRepository ? 'in-force/project-repository/${scope.receiptKey}' : 'in-force/${scope.receiptKey}';

/// One commit made here and pushed in one repository of a project: the `base` it was made on, and, for a replacement,
/// the login it `replaced` and the fingerprint it replaced there, `old`.
typedef MadeHere = ({String base, String revision, String? replaced, String? old});

/// The commits kept as made here in [scope]'s access, or with [projectRepository] in its own repository, oldest first;
/// one kept before they were kept each on its own base reads as the one it names.
List<MadeHere> madeHereIn(RecoveryReceipts receipts, RecoveryScope scope, {bool projectRepository = false}) {
  final kept = receipts.read(_inForceKey(scope, projectRepository: projectRepository));
  final entries = kept?['made'] is List ? kept!['made']! as List : [kept];
  return [
    for (final entry in entries)
      if (entry is Map && entry['base'] is String && entry['revision'] is String)
        (
          base: entry['base']! as String,
          revision: entry['revision']! as String,
          replaced: entry['replaced'] is String ? entry['replaced']! as String : null,
          old: entry['old'] is String ? entry['old']! as String : null,
        ),
  ];
}

Future<void> _keepMadeHere(RecoveryReceipts receipts, String key, List<MadeHere> made) => made.isEmpty
    ? receipts.forget(key)
    : receipts.keep(key, {
        'made': [
          for (final entry in made)
            {'base': entry.base, 'revision': entry.revision, 'replaced': entry.replaced, 'old': entry.old},
        ],
      });

/// The commits kept in [made] that a read at [read] does not hold yet: the one made on it, the one made on that, and so
/// on, oldest first.
List<MadeHere> _after(List<MadeHere> made, String? read) {
  final chain = <MadeHere>[];
  var at = read;
  while (at != null && chain.length < made.length) {
    final next = made.where((entry) => entry.base == at).lastOrNull;
    if (next == null) break;
    chain.add(next);
    at = next.revision;
  }
  return chain;
}

/// Keeps [revision], made here on [base] and pushed, as a commit in force for a project's access, or with
/// [projectRepository] for its own repository; [replaced] is the login whose key it replaced there, and [old] that
/// key's fingerprint, when it is a replacement.
///
/// Each commit keeps its own base, so a read that holds one of a chain still finds every one made after it.
Future<void> keepMadeInForce(
  RecoveryReceipts receipts,
  RecoveryScope scope, {
  required String base,
  required String revision,
  String? replaced,
  String? old,
  bool projectRepository = false,
}) async {
  if (scope.kind != RecoveryKind.project) return;
  final made = madeHereIn(receipts, scope, projectRepository: projectRepository);
  if (made.any((entry) => entry.revision == revision)) return;
  await _keepMadeHere(receipts, _inForceKey(scope, projectRepository: projectRepository), [
    ...made,
    (base: base, revision: revision, replaced: replaced, old: old),
  ]);
}

/// Forgets every commit kept as made here in [scope], or with [projectRepository] in the project's own repository,
/// once Core said the list moved past them.
Future<void> forgetMadeInForce(RecoveryReceipts receipts, RecoveryScope scope, {bool projectRepository = false}) async {
  final key = _inForceKey(scope, projectRepository: projectRepository);
  if (scope.kind == RecoveryKind.project && receipts.read(key) != null) await receipts.forget(key);
}

/// Forgets the commits kept as made here that a read at [read] holds, or that a list moved past: only those made on it,
/// one after another, are kept, and those [stillDone] keeps as done whatever the read holds.
Future<void> forgetShownInForce(
  RecoveryReceipts receipts,
  RecoveryScope scope,
  String? read, {
  bool projectRepository = false,
  bool Function(MadeHere made)? stillDone,
}) async {
  if (scope.kind != RecoveryKind.project) return;
  final made = madeHereIn(receipts, scope, projectRepository: projectRepository);
  final unshown = _after(made, read);
  final kept = [
    for (final entry in made)
      if (unshown.contains(entry) || (stillDone?.call(entry) ?? false)) entry,
  ];
  if (kept.length == made.length) return;
  await _keepMadeHere(receipts, _inForceKey(scope, projectRepository: projectRepository), kept);
}

/// The login whose key the newest replacement kept as made here after [read] replaced, or null when none of them is
/// one; with [projectRepository], those made in the project's own repository by its backup key.
String? madeInForceReplaced(
  RecoveryReceipts receipts,
  RecoveryScope scope,
  String? read, {
  bool projectRepository = false,
}) => _after(
  madeHereIn(receipts, scope, projectRepository: projectRepository),
  read,
).map((entry) => entry.replaced).nonNulls.lastOrNull;

/// The commit in force for [scope] when [read] is what its access, or with [projectRepository] its own repository, was
/// last read at: the newest made here after it.
String? madeInForce(RecoveryReceipts receipts, RecoveryScope scope, String? read, {bool projectRepository = false}) {
  final newest = _after(madeHereIn(receipts, scope, projectRepository: projectRepository), read).lastOrNull;
  if (newest == null) return read;
  try {
    return checkedRegistryRevision(newest.revision);
  } on FormatException {
    return read;
  }
}

/// Making one backup key for one list, under a request kept until its commit is pushed.
///
/// **One key per request**: a terminal that ended without a readable answer is retried under the same ID and base,
/// which Core answers without a second key; the new file's place is asked again and never kept. A request is kept as
/// uncertain while its terminal runs; once an end was uncertain, only Core's proof that nothing was made under it, or
/// the person's Forget, drops it.
class BackupKeyMaking {
  /// Constructor taking the list, the commit in force, Core's boundary and where the request is kept.
  BackupKeyMaking({required this.scope, required this.base, required this.core, required this.receipts, Random? random})
    : _random = random ?? Random.secure();

  /// The same making on [base], read within its running attempt, which keeps holding the registry checkout for it.
  BackupKeyMaking on(String base) =>
      BackupKeyMaking(scope: scope, base: base, core: core, receipts: receipts, random: _random).._hold = _hold;

  // The token the running attempt holds the registry checkout by, made for it alone; null outside an attempt.
  Object? _hold;

  /// The list the backup key stands in for its single admin.
  final RecoveryScope scope;

  /// The commit in force now, absent when only a kept request is finished; a kept request keeps its own.
  final String? base;

  /// Core's boundary, for the registry checkout's prepare and push.
  final KeyRecoveryCore core;

  /// Where the request is kept.
  final RecoveryReceipts receipts;

  final Random _random;

  /// Where every backup-key request is kept, before its list's key.
  static const keyPrefix = 'backup-make/';

  /// Where the backup-key request for [scope] is kept.
  static String keyOf(RecoveryScope scope) => '$keyPrefix${scope.receiptKey}';

  String get _key => keyOf(scope);

  /// Reads a kept request field by field, or null when [kept] is none or cannot be read.
  static _BackupRequest? _read(Map<String, Object?>? kept) {
    if (kept == null) return null;
    final id = kept['id'];
    final base = kept['base'];
    final revision = kept['revision'];
    // A request kept without the flag is taken as uncertain: keeping it is safe, dropping it is not.
    final uncertain = kept['uncertain'] ?? true;
    final earlier = kept['earlier'] ?? uncertain;
    try {
      if (id is! String ||
          !operationIdPattern.hasMatch(id) ||
          base is! String ||
          revision != null && revision is! String ||
          uncertain is! bool ||
          earlier is! bool) {
        return null;
      }
      return (
        scope: RecoveryScope.read(kept['scope']),
        id: id,
        base: checkedRegistryRevision(base),
        revision: revision == null ? null : checkedRegistryRevision(revision as String),
        uncertain: uncertain,
        earlier: earlier,
      );
    } on FormatException {
      return null;
    }
  }

  _BackupRequest? get _kept {
    final kept = _read(receipts.read(_key));
    return kept?.scope == scope ? kept : null;
  }

  Future<void> _keep({
    required String id,
    required String base,
    String? revision,
    required bool uncertain,
    required bool earlier,
  }) => receipts.keep(_key, {
    'scope': scope.stored,
    'id': id,
    'base': base,
    'revision': revision,
    'uncertain': uncertain,
    'earlier': earlier,
  });

  /// The commit Core made whose push is still owed, or null.
  String? get unpublished => _kept?.revision;

  /// Whether a request is kept, so the next attempt repeats it.
  bool get pending => _kept != null;

  /// The kept request's ID, or null.
  String? get requestId => _kept?.id;

  /// Whether an attempt ended without a readable answer, so Core may have made the key and its commit already.
  bool get uncertain => _kept?.uncertain ?? false;

  /// Whether an attempt for this list runs now, from asking where its file goes until its terminal's program ended.
  bool get running => RecoveryRuns.of(receipts).runs(_key);

  /// Whether an attempt for any list runs now over [receipts].
  static bool anyRunning(RecoveryReceipts receipts) =>
      RecoveryRuns.of(receipts).keys.any((key) => key.startsWith(keyPrefix));

  /// Runs one attempt as [work], counted as running throughout; a second for the same list, or one in the registry
  /// checkout beside any other change there, is refused meanwhile.
  ///
  /// For a registry list it holds the registry checkout, where Core commits, from its start to the end of its push,
  /// under a token of its own: [start], [ended] and [publish] take no hold of their own, so called alone they leave
  /// nothing held. A project's backup key is made in its own repository and holds nothing.
  Future<T> attempt<T>(Future<T> Function() work) async {
    final runs = RecoveryRuns.of(receipts);
    if (runs.runs(_key)) throw RegistryRefusal('A backup key for ${scope.words} is being made already.');
    if (runs.whyNotStart(_key, scope) case final why?) throw RegistryRefusal(why);
    final token = Object();
    if (scope.inRegistry) core.hold(token);
    _hold = scope.inRegistry ? token : null;
    runs.start(_key, scope);
    try {
      return await work();
    } finally {
      _hold = null;
      runs.end(_key);
      if (scope.inRegistry) core.release(token);
    }
  }

  /// Readies the making of the backup key into the new file [out] and answers the command its terminal runs.
  Future<List<String>> start(String out) async {
    final kept = _kept;
    if (kept?.revision != null) throw const RegistryRefusal('Push the backup key’s commit first.');
    final base = this.base;
    if (kept == null && base == null) throw const RegistryRefusal('The commit in force is not read. Read it again.');
    if (kept == null && scope.inRegistry) await core.prepare(scope, holder: _hold);
    final id = kept?.id ?? 'bk-${_newId()}';
    final requestBase = kept?.base ?? checkedRegistryRevision(base!);
    final command = backupMakeCommand(scope, out: out, id: id, base: requestBase);
    // Kept as uncertain before the terminal runs Core: an end never read back may have made the key.
    await _keep(id: id, base: requestBase, uncertain: true, earlier: kept?.uncertain ?? false);
    return command;
  }

  /// Takes what the terminal ended with: whether its program [started], and Core's exit [code], none when its end was
  /// not seen. A registry commit is pushed from the app's checkout.
  Future<BackupKeyMade> ended({
    required int? code,
    required String lastLine,
    required String out,
    bool started = true,
  }) async {
    final kept = _kept;
    if (kept == null) throw const RegistryRefusal('No backup key is being made.');
    if (_terminalMadeNothing(started: started, code: code)) {
      final typed = Identity.typedRefusal(lastLine);
      // A project's backup key is made in its own repository: the access file's record stays.
      if (typed?.reason == 'base-moved') await forgetMadeInForce(receipts, scope, projectRepository: true);
      // After an uncertain end the key may exist already: only the same request answers it, or Core's proof of none.
      if (!kept.earlier || _provesNoneMade(typed?.reason)) {
        await receipts.forget(_key);
      } else {
        await _keep(id: kept.id, base: kept.base, uncertain: true, earlier: true);
      }
      throw RecoveryRefused(
        backupKeyWords(code, typed?.reason, typed?.words, started: started),
        code: code ?? -1,
        reason: typed?.reason,
      );
    }
    // From here Core ran: anything but the exact answer leaves the request kept as uncertain.
    final made = backupMadeFrom(scope, code: code, lastLine: lastLine, id: kept.id, out: kept.earlier ? null : out);
    if (!made.published) {
      await _keep(id: kept.id, base: kept.base, revision: made.revision, uncertain: false, earlier: false);
      await publish();
    }
    await receipts.forget(_key);
    await keepMadeInForce(receipts, scope, base: kept.base, revision: made.revision, projectRepository: true);
    return BackupKeyMade(fingerprint: made.fingerprint, revision: made.revision, published: true, file: made.file);
  }

  /// Drops a kept request on the person's word, never while its attempt runs; what Core made stays.
  ///
  /// A made commit owed its push is dropped only when [made] names it, as the confirmation the person read did: it
  /// stays in the registry checkout, to be pushed or dropped there by hand.
  Future<void> forget({String? made}) async {
    final revision = _kept?.revision;
    if (running || revision != null && revision != made) return;
    await receipts.forget(_key);
  }

  /// Pushes the commit Core made in the registry checkout, once; a refused push keeps it for the next try.
  Future<void> publish() async {
    final kept = _kept;
    final revision = kept?.revision;
    if (kept == null || revision == null) return;
    await core.publish(scope, revision, base: kept.base, id: kept.id, holder: _hold);
    await receipts.forget(_key);
  }

  String _newId() => List.generate(8, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

/// A backup-key request as kept: its list, ID and base, the commit once made, and whether it may be made already.
///
/// `earlier` is whether an attempt before the running one ended uncertain, which a proven-nothing-made end restores.
typedef _BackupRequest = ({
  RecoveryScope scope,
  String id,
  String base,
  String? revision,
  bool uncertain,
  bool earlier,
});

/// The SHA256 fingerprint of an `ssh-ed25519 AAAA...` key, as OpenSSH prints it.
String sshFingerprint(String key) {
  final parts = key.trim().split(RegExp(r'\s+'));
  if (parts.length < 2 || parts.first != 'ssh-ed25519') throw const FormatException('Not an Ed25519 key.');
  final blob = base64.decode(parts[1]);
  return 'SHA256:${base64.encode(sha256.convert(blob).bytes).replaceAll('=', '')}';
}

/// [host]'s `access.yml` with [person]'s pin moved from [oldFingerprint] to [newFingerprint], everything else kept.
String hostAccessFileReplacing(
  RegistryHost host, {
  required String person,
  required String oldFingerprint,
  required String newFingerprint,
}) {
  if (host.adminFingerprints[person] != oldFingerprint) {
    throw FormatException('${host.host} does not pin $person under the key to replace.');
  }
  final admins = {...host.adminFingerprints, person: newFingerprint};
  // JSON strings are YAML scalars, so no value can break out of its line.
  return [
    'admins:',
    for (final MapEntry(:key, :value) in admins.entries) '  ${jsonEncode(key)}: ${jsonEncode(value)}',
    'projects:',
    for (final each in host.projects) ...[
      '  - name: ${jsonEncode(each.name)}',
      '    admin: ${jsonEncode(each.admin)}',
      '    access_repository: ${jsonEncode(each.accessRepository)}',
    ],
    '',
  ].join('\n');
}

/// `owners.yml` with the working entry of [login] in [scope]'s list moved from [oldFingerprint] to [newKey].
///
/// Only that entry's `key:` line changes; a backup entry, another list or a flow-style file is refused.
String ownersFileReplacing(
  String text,
  RecoveryScope scope, {
  required String login,
  required String oldFingerprint,
  required String newKey,
}) {
  if (scope.kind != RecoveryKind.owner && scope.kind != RecoveryKind.hostAdmin) {
    throw const FormatException('owners.yml holds only owners and host admins.');
  }
  sshFingerprint(newKey);
  final lines = text.split('\n');
  int indent(String line) => line.length - line.trimLeft().length;
  bool blank(String line) => line.trim().isEmpty || line.trimLeft().startsWith('#');
  String value(String line) {
    final raw = line.substring(line.indexOf(':') + 1).trim();
    if (raw.length >= 2 && (raw.startsWith('"') && raw.endsWith('"') || raw.startsWith("'") && raw.endsWith("'"))) {
      return raw.substring(1, raw.length - 1);
    }
    return raw;
  }

  // The block holding the list: from the line after its header to the first line indented no deeper than it.
  (int, int) block(int from, int to, RegExp header) {
    for (var i = from; i < to; i++) {
      if (blank(lines[i]) || !header.hasMatch(lines[i])) continue;
      final depth = indent(lines[i]);
      var end = i + 1;
      while (end < to && (blank(lines[end]) || indent(lines[end]) > depth)) {
        end++;
      }
      return (i + 1, end);
    }
    throw FormatException('owners.yml has no ${scope.words}.');
  }

  var (start, end) = block(
    0,
    lines.length,
    RegExp(scope.kind == RecoveryKind.owner ? r'^owners:\s*$' : r'^host_admins:\s*$'),
  );
  if (scope.kind == RecoveryKind.hostAdmin) {
    (start, end) = block(start, end, RegExp('^\\s+["\']?${RegExp.escape(scope.name!)}["\']?:\\s*\$'));
  }
  final matches = <int>[];
  for (var i = start; i < end; i++) {
    final item = RegExp(r'^(\s*)-\s').firstMatch(lines[i]);
    if (item == null) continue;
    final depth = item.group(1)!.length;
    var stop = i + 1;
    while (stop < end && (blank(lines[stop]) || indent(lines[stop]) > depth)) {
      stop++;
    }
    String? itemLogin;
    int? keyLine;
    var backup = false;
    for (var j = i; j < stop; j++) {
      final field = lines[j].replaceFirst(RegExp(r'^\s*-\s'), '').trimLeft();
      if (field.startsWith('login:')) itemLogin = value(field);
      if (field.startsWith('key:')) keyLine = j;
      if (field.startsWith('backup:')) backup = value(field) == 'true';
    }
    if (itemLogin == login && !backup && keyLine != null) {
      final String fingerprint;
      try {
        fingerprint = sshFingerprint(value(lines[keyLine].replaceFirst(RegExp(r'^\s*-\s'), '').trimLeft()));
      } on FormatException {
        continue;
      }
      if (fingerprint == oldFingerprint) matches.add(keyLine);
    }
  }
  if (matches.length != 1) throw FormatException('${scope.words} names no single working key of $login to replace.');
  final line = lines[matches.single];
  lines[matches.single] = '${line.substring(0, line.indexOf('key:'))}key: ${jsonEncode(newKey)}';
  return lines.join('\n');
}

/// The fingerprint of the key a person card names in its body, before its signatures; null when the body names no single
/// Ed25519 key on a `key:` line of its own.
String? _cardFingerprint(String card) {
  final signature = card.indexOf('-----BEGIN SSH SIGNATURE-----');
  final body = signature < 0 ? card : card.substring(0, signature);
  final keys = [
    for (final line in body.split('\n'))
      if (RegExp(r'^key:\s*(.*?)\s*$').firstMatch(line) case final match?) match.group(1)!,
  ];
  if (keys.length != 1) return null;
  var key = keys.single;
  if (key.length >= 2 && (key.startsWith('"') && key.endsWith('"') || key.startsWith("'") && key.endsWith("'"))) {
    key = key.substring(1, key.length - 1);
  }
  try {
    return sshFingerprint(key);
  } on FormatException {
    return null;
  }
}

/// Refuses an `owners.yml` change that is more than one entry's `key:` line.
void checkOneKeyChanged(String before, String after) {
  final old = before.split('\n');
  final now = after.split('\n');
  final changed = [
    if (old.length == now.length)
      for (var i = 0; i < old.length; i++)
        if (old[i] != now[i]) i,
  ];
  final keyLine = RegExp(r'^(\s*(?:-\s+)?)key:');
  if (old.length != now.length ||
      changed.length != 1 ||
      keyLine.firstMatch(old[changed.single])?.group(1) != keyLine.firstMatch(now[changed.single])?.group(1) ||
      !keyLine.hasMatch(now[changed.single])) {
    throw const RecoveryRefused(
      'The change to owners.yml is more than one key. Nothing was filed.',
      code: 0,
      reason: 'backup-only-own',
    );
  }
}

/// Private copies of a reviewed card that Core is handed, each in a folder of its own that only this user reaches from
/// its creation, the file restricted before its text is written.
///
/// On Windows, where a folder is made with its parent's access and restricted only after, each copy's folder is made
/// under a private root this program restricted once, so it is never reachable by another account. A copy is removed
/// once Core ran, and a removal that fails throws nothing; what a crash left behind is swept at start and when the
/// next copy is made.
class PrivateCards {
  /// Constructor taking the folder copies are made under, the system's temporary folder by default, and the writer
  /// that makes them private.
  PrivateCards({String? root, HostFileWriter? writer})
    : root = root ?? Directory.systemTemp.path,
      _writer = writer ?? HostFileWriter();

  /// Where each copy's folder is made, or on Windows the private root that holds them.
  final String root;

  final HostFileWriter _writer;

  /// The start of each copy's folder name.
  static const prefix = 'porelo-card-';

  /// The private root copies are made under on Windows, inside [root].
  static const windowsRoot = 'porelo-cards';

  /// What a login that names a card copy must be: no separator, no dot, nothing a path reads otherwise.
  static final login = RegExp(r'^[a-z][a-z0-9-]{0,31}$');

  // The folders of copies Core may still read, made in this program, as normalized absolute paths: never swept.
  static final _live = <String>{};

  // Making a copy's folder and marking it live, and every sweep, run one after another: a sweep never meets a folder
  // made and not yet marked.
  static Future<void> _lock = Future<void>.value();

  // The private root, made once.
  Future<String>? _home;

  static Future<T> _locked<T>(Future<T> Function() work) {
    final result = _lock.then((_) => work());
    _lock = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  static String _normal(String folder) => path.normalize(path.absolute(folder));

  /// Where each copy's folder is made: [root], or on Windows the private root inside it, made private before first use.
  Future<String> _folder() => _home ??= () async {
    if (!_writer.isWindows) return _normal(root);
    final home = _normal(path.join(root, windowsRoot));
    await privateDirectory(Directory(home), writer: _writer);
    return home;
  }();

  /// Writes [content] as `<login>.card` into a new private folder and answers the file's path.
  ///
  /// [login] must be a login, or nothing is made: anything else could name a file outside the folder.
  Future<String> copy(String login, String content) async {
    if (!PrivateCards.login.hasMatch(login)) {
      throw RecoveryRefused('“$login” is no login a card can be named after. Nothing was handed to Core.', code: 0);
    }
    final folder = await _locked(() async {
      final home = await _folder();
      await _sweepIn(home);
      final made = await _writer.createPrivateTemporary(Directory(home), prefix: prefix);
      _live.add(_normal(made.path));
      return made;
    });
    final file = File(path.join(folder.path, '$login.card'));
    try {
      await file.create(exclusive: true);
      await _writer.protect(file);
      await file.writeAsString(content, flush: true);
      return file.path;
    } catch (_) {
      await drop(file.path);
      rethrow;
    }
  }

  /// Removes the copy [file] and its folder; one that cannot be removed now is swept later.
  Future<void> drop(String file) async {
    final folder = _normal(path.dirname(file));
    if (!_live.remove(folder)) return;
    try {
      await Directory(folder).delete(recursive: true);
    } on FileSystemException {
      // Core's answer counts more than the copy: the next sweep removes it.
    }
  }

  /// Removes every copy left behind that this program does not hand Core now: at start, and before each copy.
  Future<void> sweep() => _locked(() async {
    try {
      await _sweepIn(await _folder());
    } on Exception {
      // Nothing to sweep where the folder cannot be made private or listed.
    }
  });

  static Future<void> _sweepIn(String home) async {
    try {
      await for (final entry in Directory(home).list(followLinks: false)) {
        if (entry is! Directory ||
            !path.basename(entry.path).startsWith(prefix) ||
            _live.contains(_normal(entry.path))) {
          continue;
        }
        try {
          await entry.delete(recursive: true);
        } on FileSystemException {
          // Another user's, or still locked: left as it is.
        }
      }
    } on FileSystemException {
      // Nothing to sweep where nothing can be listed.
    }
  }
}

/// Reads [file], a new card or `owners.yml`, from the registry checkout, refusing one, or its folder, that is a link or
/// no plain file: Core refuses such a file, and a copy of what it points to would pass that refusal by.
Future<String> readRegularFile(String file) async {
  final folder = await FileSystemEntity.type(path.dirname(file), followLinks: false);
  final card = await FileSystemEntity.type(file, followLinks: false);
  if (folder != FileSystemEntityType.directory || card != FileSystemEntityType.file) {
    throw RecoveryRefused(
      '$file in the registry checkout is a link or no plain file, which Core refuses. Nothing was handed to Core.',
      code: 0,
    );
  }
  return File(file).readAsString();
}

/// Core's replacement verbs on this computer: `project access replace` and the registry's own filings.
class CliKeyRecoveryCore implements KeyRecoveryCore {
  /// Constructor taking the project adapters, the shared registry, the proven identity and a process runner.
  CliKeyRecoveryCore({
    required this.actor,
    this.project,
    this.registry,
    RunHere? run,
    Future<String> Function(String file)? readFile,
    PrivateCards? cards,
  }) : _run = run ?? runHere,
       _readFile = readFile ?? readRegularFile,
       _cards = cards ?? PrivateCards();

  /// The person at this computer as Core proved them.
  final HostAdminIdentity? Function() actor;

  /// The project's Core adapter, which knows its folder and whether the person is its admin here.
  final ProjectAccessCoreAdapter? Function(String project)? project;

  /// The shared accepted registry, for host access files and owners.yml.
  final Registry? registry;

  final RunHere _run;
  final Future<String> Function(String file) _readFile;
  final PrivateCards _cards;

  @override
  void hold(Object holder) => registry?.hold(holder);

  @override
  void release(Object holder) => registry?.release(holder);

  @override
  Future<String> copyCard(String login, String content) => _cards.copy(login, content);

  @override
  Future<void> dropCard(String file) => _cards.drop(file);

  /// Refuses a run that is not [holder] while another holds the registry checkout, or, when [holder] holds nothing,
  /// while a registry read or filing runs: the checkout's files may be another state than Core's answer then.
  static void _checkoutStill(Registry registry, Object? holder, {int code = 0}) {
    if (registry.holds(holder)) return;
    if (registry.held) throw RecoveryRefused(Registry.heldWords, code: code);
    if (registry.busy) throw RecoveryRefused('A registry read still runs; try again once it ended.', code: code);
  }

  @override
  Future<RegistryRefusal?> refusal(RecoveryScope scope, {bool backup = false}) async {
    final me = actor();
    if (me == null) return const RegistryRefusal('Read your own key and card first.');
    // The backup key signs for its own admin alone; Core refuses anyone else as not-sole or not-the-backup.
    if (backup) return null;
    if (scope.kind == RecoveryKind.project) {
      final adapter = project?.call(scope.name!);
      if (adapter == null) return const RegistryRefusal('This project’s access is not connected to Core here.');
      final standing = await adapter.standing(scope.name!, login: me.login);
      return standing.may ? null : ProjectAccessNotAdmin(standing);
    }
    final registry = _registry();
    final accepted = registry.accepted!;
    final RegistryFiling filing;
    final List<RegistryOwner> signers;
    if (scope.kind == RecoveryKind.hostAccess) {
      filing = RegistryFiling(RegistryFilingKind.hostAccess, host: scope.name);
      signers = accepted.adminsOf(scope.name!);
    } else {
      filing = const RegistryFiling(RegistryFilingKind.owners);
      signers = [
        for (final owner in accepted.owners)
          if (!owner.backup) owner,
      ];
    }
    if (signers.any((signer) => signer.login == me.login && signer.fingerprint == me.fingerprint)) return null;
    return RegistryRefusal(
      'Only ${scope.whoWords} may replace a key in ${scope.words}.',
      whoMay: [
        for (final contact in registry.whoMay(filing))
          if (contact.login != me.login) contact,
      ],
    );
  }

  @override
  Future<void> checkReviewed(RecoveryReview review, {Object? holder}) async {
    final registry = this.registry;
    final accepted = registry?.accepted;
    // The new card is read from the checkout that holds it, which only a registry read moves, and Core's answer to that
    // read is what is compared: while one runs, or another run holds the checkout, the card on disk may already be
    // another. A run holding the checkout meets none running, only some waiting for it. A project's run commits nothing
    // there and hands Core only the exact card text reviewed, so it is never refused for a read or a hold.
    if (registry != null && review.scope.inRegistry) _checkoutStill(registry, holder);
    if (registry == null || accepted == null || registry.problem != null) {
      throw const RecoveryRefused(reviewMoved, code: 0);
    }
    if (review.scope.inRegistry && accepted.revision != review.base) throw const RecoveryRefused(reviewMoved, code: 0);
    final card = registry.people.where((card) => card.login == review.login).firstOrNull;
    if (card == null ||
        !card.trusted ||
        card.fingerprint != review.newFingerprint ||
        review.card != path.join(registry.checkout.folder, 'people', '${review.login}.card')) {
      throw const RecoveryRefused(reviewMoved, code: 0);
    }
  }

  @override
  Future<String?> fileFor(RecoveryReview review, {Object? holder}) async {
    if (review.backup || review.scope.kind == RecoveryKind.project) return _reviewedCard(review, holder);
    switch (review.scope.kind) {
      case RecoveryKind.project:
        throw StateError('A project hands Core its card.');
      case RecoveryKind.hostAccess:
        final host = _registry().hosts.where((host) => host.host == review.scope.name).firstOrNull;
        if (host == null) throw const RegistryRefusal('The registry lists no such host.');
        return hostAccessFileReplacing(
          host,
          person: review.login,
          oldFingerprint: review.oldFingerprint,
          newFingerprint: review.newFingerprint,
        );
      case RecoveryKind.hostAdmin || RecoveryKind.owner:
        final before = await _readFile(path.join(_registry().checkout.folder, 'owners.yml'));
        final content = ownersFileReplacing(
          before,
          review.scope,
          login: review.login,
          oldFingerprint: review.oldFingerprint,
          newKey: review.newKey,
        );
        checkOneKeyChanged(before, content);
        return content;
    }
  }

  /// The new card of [review] as the checkout holds it, read once while nothing moves the checkout, and only when it
  /// is the exact card the review read: the checkout's file moves with the next refresh, the kept copy does not.
  Future<String> _reviewedCard(RecoveryReview review, Object? holder) async {
    final registry = this.registry;
    if (registry == null) throw const RecoveryRefused(reviewMoved, code: 0);
    // A project's run takes the card only as the exact text reviewed, whatever runs in the checkout meanwhile.
    final atRest = review.scope.inRegistry;
    if (atRest) _checkoutStill(registry, holder);
    final read = registry.accepted;
    final card = await _readFile(review.card);
    if (atRest) _checkoutStill(registry, holder);
    if (!identical(registry.accepted, read) || registry.problem != null || !review.isReviewedCard(card)) {
      throw const RecoveryRefused(reviewMoved, code: 0);
    }
    return card;
  }

  @override
  Future<RecoveryFiled> replace(
    RecoveryReview review,
    String id, {
    String? content,
    bool again = false,
    Object? holder,
  }) async {
    if (!operationIdPattern.hasMatch(id)) throw const FormatException('Not a request ID.');
    final base = checkedRegistryRevision(review.base);
    if (review.scope.kind == RecoveryKind.project) {
      final adapter = project?.call(review.scope.name!);
      if (adapter == null) throw const RegistryRefusal('This project’s access is not connected to Core here.');
      // The card as reviewed, never the checkout's file, which a refresh may change before Core reads it.
      if (content == null || !review.isReviewedCard(content)) throw const RecoveryRefused(reviewMoved, code: 0);
      final Ran ran;
      final card = await copyCard(review.login, content);
      try {
        ran = await _run('porelo', [
          'project',
          'access',
          'replace',
          '--project',
          review.scope.name!,
          '--person',
          review.login,
          '--card',
          card,
          '--base',
          base,
          '--id',
          id,
          '--json',
        ], inDirectory: adapter.directory);
      } finally {
        await dropCard(card);
      }
      if (ran.code != 0) {
        final typed = Identity.typedRefusal(ran.out);
        throw RecoveryRefused(typed?.words ?? _exitWords(ran.code), code: ran.code, reason: typed?.reason);
      }
      final answer = jsonDecode(ran.out);
      final revision = answer is Map<String, dynamic> ? answer['revision'] : null;
      if (revision is! String) throw const FormatException('Core did not answer the access revision.');
      return RecoveryFiled(revision: checkedRegistryRevision(revision), published: true);
    }
    if (content == null) throw const FormatException('A registry replacement names no file to file.');
    // A request tried again was checked when it was made; its own unpushed commit keeps the registry from reading clean.
    final registry = again ? this.registry : _registry();
    if (registry == null) throw const RegistryRefusal('The registry has not been read here yet.');
    // Core commits in the checkout: never beside another run holding it.
    if (registry.held && !registry.holds(holder)) {
      throw const RecoveryRefused(Registry.heldWords, code: 65);
    }
    final hostAccess = review.scope.kind == RecoveryKind.hostAccess;
    final kind = hostAccess ? RegistryFilingKind.hostAccess : RegistryFilingKind.owners;
    // The person names the card the registry must trust, so Registry's trusted-card check applies.
    final filing = RegistryFiling(
      kind,
      host: hostAccess ? review.scope.name : null,
      person: review.login,
      id: id,
      base: base,
      content: content,
    );
    if (again) {
      await registry.checkout.prepareRetry(base: base, file: _changedFile(review.scope), content: content);
    } else {
      if (registry.unavailable(filing, holder: holder) case final why?) {
        throw RecoveryRefused(why, code: 65, whoMay: registry.whoMay(filing));
      }
      await registry.checkout.prepareFiling();
    }
    final RegistryFiled made;
    try {
      made = await registry.core.file(registry.checkout.folder, filing);
    } on RegistryFilingRefused catch (refused) {
      // Core's own exit code says whether a commit may be made: 69 and 70 can come after it.
      throw RecoveryRefused(refused.words, code: refused.code, reason: refused.reason, whoMay: registry.whoMay(filing));
    } on RegistryRefusal catch (refused) {
      // Without Core's exit code nothing proves the commit was not made.
      throw RecoveryRefused(refused.words, code: 70, whoMay: registry.whoMay(filing));
    }
    // Pushed by [publish], so a refused push keeps this commit for Retry instead of filing again.
    return RecoveryFiled(revision: checkedRegistryRevision(made.revision), published: false);
  }

  @override
  Future<void> prepare(RecoveryScope scope, {Object? holder}) async {
    if (!scope.inRegistry) return;
    final registry = _registry();
    _checkoutStill(registry, holder);
    await registry.checkout.prepareFiling();
  }

  @override
  Future<void> publish(
    RecoveryScope scope,
    String revision, {
    required String base,
    required String id,
    Object? holder,
  }) async {
    if (!scope.inRegistry) return;
    final registry = this.registry;
    if (registry == null) throw const RegistryRefusal('The registry has not been read here yet.');
    if (registry.held && !registry.holds(holder)) throw const RegistryRefusal(Registry.heldWords);
    // Core makes a backup key's commit on the kept base or on the commit it read last, which may have moved since.
    await registry.checkout.publishMade(
      checkedRegistryRevision(revision),
      base: checkedRegistryRevision(base),
      id: id,
      file: _changedFile(scope),
      lastRead: registry.accepted?.revision,
    );
    // The run holding the checkout reads it again itself, one read after another: a refresh would wait for its end.
    if (holder != null && registry.holds(holder)) {
      await registry.readAgainHeld(holder);
    } else {
      await registry.refresh();
    }
  }

  /// The one file a change of [scope] commits in the registry checkout, as Git names it, with `/` on every system.
  static String _changedFile(RecoveryScope scope) =>
      scope.kind == RecoveryKind.hostAccess ? 'hosts/${scope.name}/access.yml' : 'owners.yml';

  Registry _registry() {
    final registry = this.registry;
    if (registry == null || registry.accepted == null) {
      throw const RegistryRefusal('The registry has not been read here yet.');
    }
    if (registry.problem != null) {
      throw const RegistryRefusal('The newest registry state was not accepted. Refresh it before making a change.');
    }
    return registry;
  }

  static String _exitWords(int code) => switch (code) {
    64 => 'Core did not take this replacement.',
    65 => 'Core refused the replacement.',
    66 => 'The project is not followed here, or its access repository was not reached.',
    69 => 'The replacement could not be pushed. Retry: the same request answers the same commit.',
    _ => 'Core could not make the replacement.',
  };
}

/// Brings a replacing registry commit to a host over its pinned tunnel and reads back what it confirms.
///
/// A stolen key counts as locked only when the host names the person locked at that commit; a lost key's replacement
/// only when the host applied that commit. A project's access commit never goes this way: it is no registry commit.
class RegistryRevocationHosts implements RevocationHosts {
  /// Constructor taking the host registry transport.
  RegistryRevocationHosts(this.transport);

  /// The pinned host's checked registry intake and sync.
  final HostRegistryTransport transport;

  @override
  Future<HostLock> deliver(RecoveryReview review, String host, String revision) async {
    if (review.scope.kind == RecoveryKind.project) {
      return HostLockPending(
        host,
        'Not delivered yet: a project’s access change reaches its host through the project’s own delivery, which '
        'is not connected here. The host takes it at its next sync.',
      );
    }
    await transport.upload(host, revision);
    final status = await transport.sync(host, revision);
    if (status.host != host) return HostLockPending(host, 'Not on the host yet: it answered for another host.');
    if (status.revision != revision) {
      final applied = status.revision.length > 12 ? status.revision.substring(0, 12) : status.revision;
      return HostLockPending(host, 'Not on the host yet: it applied ${applied.isEmpty ? 'nothing' : applied}.');
    }
    if (!review.stolen) return HostReplaced(host);
    return status.people[review.login] == 'locked'
        ? HostLocked(host)
        : HostLockPending(host, 'Not locked on the host yet: it does not name ${review.login} locked.');
  }
}

/// Where a recovery dialog gets the list as read now and Core's and the hosts' boundaries.
abstract interface class KeyRecoveryEntry {
  /// The list of [scope] as read now; throws a [RegistryRefusal] when it cannot be read.
  Future<RecoverySituation> situation(RecoveryScope scope);

  /// The registry's lists an owner may change: the owners and each host's admins.
  List<RecoveryScope> get registryScopes;

  /// Core's boundary.
  KeyRecoveryCore get core;

  /// The hosts' boundary.
  RevocationHosts get hosts;

  /// Where pending requests are kept.
  RecoveryReceipts get receipts;

  /// The lists a backup key is being made for here and not finished: offered again until pushed.
  List<RecoveryScope> get keptBackups;
}

/// Keeps pending requests in the interface's settings.
class SettingsReceipts implements RecoveryReceipts {
  /// Constructor taking the settings.
  SettingsReceipts(this.settings);

  /// The interface's settings.
  final Settings settings;

  @override
  Map<String, Object?>? read(String key) => settings.keyRecovery(key);

  @override
  Future<void> keep(String key, Map<String, Object?> receipt) => settings.rememberKeyRecovery(key, receipt);

  @override
  Future<void> forget(String key) => settings.forgetKeyRecovery(key);

  @override
  List<String> get keys => settings.keyRecoveryKeys;
}

/// Reads each list from the shared registry and the project's verified access, as Core accepted them.
class KeyRecoveryServices implements KeyRecoveryEntry {
  /// Constructor taking Core's and the hosts' boundaries, the registry, the projects and the proven identity.
  KeyRecoveryServices({
    required this.core,
    required this.hosts,
    required this.registry,
    required this.actor,
    required this.receipts,
    this.projectView,
    this.projectBackup,
    Future<String> Function(String file)? readFile,
  }) : _readFile = readFile ?? readRegularFile;

  final Future<String> Function(String file) _readFile;

  @override
  final KeyRecoveryCore core;

  @override
  final RevocationHosts hosts;

  @override
  final RecoveryReceipts receipts;

  /// The shared accepted registry.
  final Registry registry;

  /// The person at this computer as Core proved them.
  final HostAdminIdentity? Function() actor;

  /// The verified access of a project, absent when it is not read.
  final ProjectAccessView? Function(String project)? projectView;

  /// Whether a backup key is filed for a project's login; Core's verify does not answer it to this interface yet.
  final bool Function(String project, String login)? projectBackup;

  @override
  List<RecoveryScope> get registryScopes => {
    if (registry.accepted != null) ...[
      const RecoveryScope.owner(),
      for (final host in registry.accepted!.hostAdmins.keys) RecoveryScope.hostAdmin(host),
    ],
    // A kept replacement is reachable without a fresh read: its own commit may be what keeps the read from passing.
    for (final key in receipts.keys)
      if (_keptReview(key)?.scope case final scope?)
        if (scope.kind == RecoveryKind.owner || scope.kind == RecoveryKind.hostAdmin) scope,
  }.toList();

  @override
  List<RecoveryScope> get keptBackups => [
    for (final key in receipts.keys)
      if (key.startsWith(BackupKeyMaking.keyPrefix))
        // A request that does not read is never offered: making a backup key anew writes over it.
        if (BackupKeyMaking._read(receipts.read(key))?.scope case final scope? when key == BackupKeyMaking.keyOf(scope))
          scope,
  ];

  RecoveryReview? _keptReview(String key) {
    if (key.startsWith(BackupKeyMaking.keyPrefix)) return null;
    try {
      final review = RecoveryReview.read(receipts.read(key)?['review']);
      return review.scope.receiptKey == key ? review : null;
    } on FormatException {
      return null;
    }
  }

  /// The list as the kept replacement for [scope] reviewed it, enough to resume that replacement and nothing else.
  RecoverySituation? _kept(RecoveryScope scope) {
    final review = _keptReview(scope.receiptKey);
    if (review == null) return null;
    return RecoverySituation(
      scope: scope,
      people: {review.login: review.oldFingerprint},
      cards: registry.people,
      base: review.base,
      actor: actor(),
      hosts: {review.login: review.hosts},
      checkout: registry.checkout.folder,
      soleAdmin: review.backup ? review.login : null,
      backupRegistered: review.backup,
      resumeOnly: true,
    );
  }

  @override
  Future<RecoverySituation> situation(RecoveryScope scope) async {
    // A list opened while a read runs waits for it to end: its cards are read at rest, never left unread for the
    // dialog's life. A hold is a run's own and may last; a list opened meanwhile says so and is read again later.
    await _readEnded();
    final read = await _situation(scope);
    final texts = <String, String>{};
    for (final login in read.people.keys) {
      if (read.newCard(login) case final card?) {
        if (await _cardText(card) case final text?) texts[login] = text;
      }
    }
    if (texts.isEmpty) return read;
    return RecoverySituation(
      scope: read.scope,
      people: read.people,
      cards: read.cards,
      base: read.base,
      actor: read.actor,
      hosts: read.hosts,
      checkout: read.checkout,
      soleAdmin: read.soleAdmin,
      backupRegistered: read.backupRegistered,
      resumeOnly: read.resumeOnly,
      madeHere: read.madeHere,
      madeHereReplaced: read.madeHereReplaced,
      backupBase: read.backupBase,
      backupUsed: read.backupUsed,
      cardTexts: texts,
    );
  }

  /// Ends once no fetch, read or filing runs in the registry, or once a run holds it.
  Future<void> _readEnded() {
    final registry = this.registry;
    if (!registry.busy || registry.held) return Future<void>.value();
    final ended = Completer<void>();
    void heard() {
      if (registry.busy && !registry.held) return;
      registry.removeListener(heard);
      ended.complete();
    }

    registry.addListener(heard);
    return ended.future;
  }

  /// The exact text of [card] as the checkout holds it for the registry read Core accepted, or null when the checkout
  /// is read, filed or held meanwhile, or holds another key: a review is made only of a card read at rest.
  Future<String?> _cardText(RegistryCard card) async {
    if (registry.busy || registry.held) return null;
    final accepted = registry.accepted;
    final String text;
    try {
      text = await _readFile(path.join(registry.checkout.folder, 'people', '${card.login}.card'));
    } on FileSystemException {
      return null;
    } on RegistryRefusal {
      // A link or no plain file: never offered for review.
      return null;
    }
    if (registry.busy || registry.held || !identical(registry.accepted, accepted)) return null;
    return _cardFingerprint(text) == card.fingerprint ? text : null;
  }

  Future<RecoverySituation> _situation(RecoveryScope scope) async {
    final accepted = registry.accepted;
    if (accepted == null || registry.problem != null) {
      // A replacement started here resumes from its own receipt; nothing new is offered without a clean read.
      if (_kept(scope) case final kept?) return kept;
      throw const RegistryRefusal(KeyRecovery.refreshBeforeReplacing);
    }
    final name = scope.name;
    RecoverySituation read({
      required Map<String, String> people,
      required String? base,
      required List<String> Function(String login) hostsOf,
      String? sole,
      bool backup = false,
      String? madeHere,
      String? madeHereReplaced,
      String? backupBase,
      String? backupUsed,
    }) => RecoverySituation(
      scope: scope,
      people: people,
      cards: registry.people,
      base: base,
      actor: actor(),
      hosts: {for (final login in people.keys) login: hostsOf(login)},
      checkout: registry.checkout.folder,
      soleAdmin: sole,
      backupRegistered: backup,
      madeHere: madeHere,
      madeHereReplaced: madeHereReplaced,
      backupBase: backupBase,
      backupUsed: backupUsed,
    );
    switch (scope.kind) {
      case RecoveryKind.project:
        final view = projectView?.call(name!);
        if (view == null || view.project != name) {
          throw const RegistryRefusal('Read the project’s verified access first.');
        }
        final admins = [
          for (final person in view.access.developers.values)
            if (person.role == 'admin' && !person.locked) person.login,
        ];
        final sole = admins.length == 1 ? admins.single : null;
        final revision = view.accessRevision;
        final people = {for (final person in view.access.developers.values) person.login: person.fingerprint};
        // A read that holds a commit made here, or a list moved past it, forgets it; those made after it stay.
        await forgetShownInForce(receipts, scope, revision);
        // A project read before a commit made here does not show it yet; the newest made after that read is in force.
        final made = madeInForce(receipts, scope, revision);
        final replaced = madeInForceReplaced(receipts, scope, revision);
        // The backup key changes the project's own repository alone, never the access file: what it made there blocks
        // nothing here. Its replacement stays done while the access file still names the key it replaced, which the
        // project file no longer does.
        await forgetShownInForce(
          receipts,
          scope,
          view.projectRevision,
          projectRepository: true,
          stillDone: (made) => made.replaced != null && made.old != null && people[made.replaced] == made.old,
        );
        // A backup key is made on the project's own repository, and on the newest commit made there here.
        final own = madeInForce(receipts, scope, view.projectRevision, projectRepository: true);
        final used = madeHereIn(receipts, scope, projectRepository: true).map((made) => made.replaced).nonNulls;
        return read(
          people: people,
          base: revision,
          hostsOf: (_) => [view.host.name],
          sole: sole,
          backup: sole != null && (projectBackup?.call(name!, sole) ?? false),
          madeHere: made != revision ? made : null,
          madeHereReplaced: replaced,
          backupBase: own,
          backupUsed: used.lastOrNull,
        );
      case RecoveryKind.hostAccess:
        final host = accepted.hosts.where((host) => host.host == name).firstOrNull;
        if (host == null) throw const RegistryRefusal('The registry lists no such host.');
        return read(people: host.adminFingerprints, base: accepted.revision, hostsOf: (_) => [host.host]);
      case RecoveryKind.hostAdmin || RecoveryKind.owner:
        final entries = scope.kind == RecoveryKind.owner ? accepted.owners : accepted.hostAdmins[name] ?? const [];
        final working = [
          for (final entry in entries)
            if (!entry.backup) entry,
        ];
        final sole = working.length == 1 ? working.single.login : null;
        return read(
          people: {for (final entry in working) entry.login: entry.fingerprint},
          base: accepted.revision,
          // An owner's key is trusted by every host; a host admin's by their host.
          hostsOf: (_) => scope.kind == RecoveryKind.owner ? [for (final host in accepted.hosts) host.host] : [name!],
          sole: sole,
          backup: sole != null && entries.any((entry) => entry.backup && entry.login == sole),
        );
    }
  }
}
