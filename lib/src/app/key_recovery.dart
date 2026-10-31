import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:porelo_frontend/client.dart' show RegistryCard, RegistryFiled, RegistryHost, RegistryOwner;

import 'host_access.dart' show HostAdminIdentity;
import 'host_access_contract.dart' show HostRegistryTransport, checkedRegistryRevision;
import 'identity.dart' show Identity, operationIdPattern;
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
  }) : people = Map.unmodifiable(people),
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

  /// The new card's file in the registry checkout, whose path alone reaches Core.
  final String card;

  /// The commit in force the change is made against.
  final String base;

  /// Every host the person has an account on.
  final List<String> hosts;

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
    if (hosts is! List || hosts.any((host) => host is! String) || stolen is! bool || backup is! bool) {
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
      stolen: stolen,
      backup: backup,
    );
  }
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

/// Where pending requests are kept across dialogs and restarts; never a backup file's place or content.
abstract interface class RecoveryReceipts {
  /// The request kept under [key], or null.
  Map<String, Object?>? read(String key);

  /// Keeps [receipt] under [key].
  Future<void> keep(String key, Map<String, Object?> receipt);

  /// Forgets what is kept under [key].
  Future<void> forget(String key);
}

/// Core's boundary for a replacement: who may, and the one signed change.
abstract interface class KeyRecoveryCore {
  /// Why the person here may not replace a key in [scope], naming who may; null when they may.
  ///
  /// With [backup], the person's own backup key signs, so only their identity is asked.
  Future<RegistryRefusal?> refusal(RecoveryScope scope, {bool backup = false});

  /// Signs [review] under [id] on its base and answers the commit; the same id on the same base answers the same one.
  Future<RecoveryFiled> replace(RecoveryReview review, String id);

  /// Readies the registry checkout before Core commits a change there in a terminal.
  Future<void> prepare(RecoveryScope scope);

  /// Pushes [revision], which Core committed in the registry checkout on [base] and did not push.
  Future<void> publish(RecoveryScope scope, String revision, {required String base});
}

/// Core refused or could not make a replacement; carries its exit code and typed reason.
class RecoveryRefused extends RegistryRefusal {
  /// Keeps the code, Core's reason and its words.
  const RecoveryRefused(super.words, {required this.code, this.reason, super.whoMay});

  /// Core's exit code, or 0 for an answer this interface refused.
  final int code;

  /// Core's fixed reason, when it named one.
  final String? reason;

  /// Whether nothing was made under the request, so the next attempt is a new decision.
  bool get nothingMade => const {64, 65, 66}.contains(code);
}

/// Whether a terminal that ended with [code] made nothing: put away before it ended, wrong use, refused, unreadable.
bool _terminalMadeNothing(int code) => code == -1 || const {64, 65, 66}.contains(code);

/// The words of a typed backup-key refusal Core gives, or of its exit code.
String backupKeyWords(int code, String? reason, String? words) {
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
    final String other => 'Core refused it ($other).$said',
    null => switch (code) {
      -1 => 'The terminal was put away before Core answered. Nothing is kept of this attempt.',
      64 => 'Core did not take this call. Nothing changed.',
      66 => 'The backup file, the project or the registry checkout could not be read. Nothing changed.',
      _ =>
        'Core may have made the commit already. Retry runs the backup key again under the same request, '
            'which answers that commit; nothing is filed anew.',
    },
  };
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

  /// Whether a backup-key commit may exist already though its answer was not read.
  bool uncertain = false;

  /// What each host confirmed.
  final Map<String, HostLock> locks = {};

  /// What went wrong last, in words.
  String? problem;

  /// Whether a call is running.
  bool busy = false;

  /// Whether the backup key's terminal was opened and has not been read back.
  bool backupRunning = false;

  String get _key => situation.scope.receiptKey;

  /// Whether the replacement started: a request is kept or a commit made.
  bool get started => requestId != null || filed != null;

  /// Whether the commit is pushed and every host confirmed it.
  bool get allConfirmed =>
      filed?.published == true && review != null && review!.hosts.every((host) => locks[host]?.confirmed ?? false);

  /// Whether the replacement is pushed, so a new backup and the person's vault recreation are offered.
  bool get replaced => filed?.published == true;

  /// Whether something started is unfinished, so Retry is offered.
  bool get unfinished => started && !allConfirmed;

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
      if (reviewed.scope != situation.scope ||
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

  /// Why [login]'s key cannot be reviewed for replacement now, or null when it can.
  String? whyNotReview(String login, {bool backup = false}) {
    if (busy) return 'Still working.';
    if (started) return 'A replacement is started here; retry it.';
    if (!situation.people.containsKey(login)) return '$login is not in ${situation.scope.words}.';
    if (situation.base == null) return 'The commit in force is not read. Read ${situation.scope.words} again.';
    if (situation.checkout == null) return 'No registry checkout holding the new card is on this computer.';
    if (situation.newCard(login) == null) {
      return 'No new key of $login that Core trusts waits in the registry. They make one with “I lost my key” under '
          'My key and card.';
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
      base: situation.base!,
      hosts: List.unmodifiable(situation.hosts[login] ?? const <String>[]),
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
    if (reviewed.stolen && !toldInPerson) {
      return 'For a stolen key, confirm that the person told you the new fingerprint themselves.';
    }
    if (reviewed.backup) return situation.whyNoBackup(reviewed.login);
    return null;
  }

  /// Signs the reviewed replacement once with the agent's key, then brings it to every host.
  Future<void> confirm({bool toldInPerson = false}) async {
    if (whyNotConfirm(toldInPerson: toldInPerson) != null || review!.backup) return;
    await _working(() async {
      final refused = await core.refusal(review!.scope);
      if (refused != null) throw refused;
      await _file();
    });
  }

  /// Why Retry cannot run now, or null when it can.
  String? get whyNotRetry {
    if (busy) return 'Still working.';
    if (!unfinished) return 'Nothing is unfinished.';
    return null;
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
    await _working(() async {
      if (filed == null) {
        final refused = await core.refusal(review!.scope);
        if (refused != null) throw refused;
        await _file();
      } else {
        await _published();
      }
    });
  }

  Future<void> _file() async {
    final reviewed = review!;
    requestId ??= _newId();
    await _keep();
    final RecoveryFiled made;
    try {
      made = await core.replace(reviewed, requestId!);
    } on RecoveryRefused catch (refused) {
      if (refused.nothingMade) {
        requestId = null;
        await _forget();
      }
      rethrow;
    }
    filed = made;
    requestId = null;
    await _keep();
    await _published();
  }

  Future<void> _published() async {
    final reviewed = review!;
    var made = filed!;
    if (!made.published) {
      await core.publish(reviewed.scope, made.revision, base: reviewed.base);
      made = filed = RecoveryFiled(revision: made.revision, published: true);
      await _keep();
    }
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
    if (allConfirmed) await _forget();
  }

  /// Why the backup key's terminal cannot be opened now, or null when it can: first after review, or as Retry.
  String? whyNotBackup({bool toldInPerson = false}) {
    final reviewed = review;
    if (busy) return 'Still working.';
    if (reviewed == null || !reviewed.backup) return 'Review the replacement with the backup key first.';
    if (filed != null) return 'It is made.';
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
      final refused = await core.refusal(reviewed.scope, backup: true);
      if (refused != null) throw refused;
      // A first attempt checks the checkout is clean; a retry may meet the commit Core made already.
      if (reviewed.scope.inRegistry && requestId == null) await core.prepare(reviewed.scope);
      requestId ??= _newId();
      await _keep();
      command = [
        'porelo',
        'identity',
        'backup-key',
        ...reviewed.scope.backupFlags!,
        '--use',
        backupFile,
        '--card',
        reviewed.card,
        '--base',
        checkedRegistryRevision(reviewed.base),
        '--id',
        requestId!,
        '--json',
      ];
      backupRunning = true;
    });
    return command;
  }

  /// Takes what the backup key's terminal ended with; publishes and delivers only the exact reviewed replacement.
  Future<void> backupEnded({required int code, required String lastLine}) async {
    final reviewed = review;
    final id = requestId;
    if (reviewed == null || id == null || !backupRunning) return;
    backupRunning = false;
    await _working(() async {
      if (_terminalMadeNothing(code)) {
        requestId = null;
        uncertain = false;
        await _forget();
        final typed = Identity.typedRefusal(lastLine);
        throw RecoveryRefused(backupKeyWords(code, typed?.reason, typed?.words), code: code, reason: typed?.reason);
      }
      final RecoveryFiled made;
      try {
        if (code != 0) {
          final typed = Identity.typedRefusal(lastLine);
          throw RecoveryRefused(backupKeyWords(code, typed?.reason, typed?.words), code: code, reason: typed?.reason);
        }
        made = checkedBackupUse(lastLine, reviewed, id);
      } on RecoveryRefused catch (refused) {
        if (refused.reason == 'backup-only-own') {
          // Core answered another change than the reviewed one: it stays where Core made it, never published.
          requestId = null;
          uncertain = false;
          await _forget();
          rethrow;
        }
        uncertain = true;
        await _keep();
        rethrow;
      }
      filed = made;
      requestId = null;
      uncertain = false;
      await _keep();
      await _published();
    });
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
      'the backup key changes only its own entry.',
      code: 0,
      reason: 'backup-only-own',
    );
  }
  return RecoveryFiled(revision: checkedRegistryRevision(revision), published: published);
}

/// What `identity backup-key --out` made.
@immutable
class BackupKeyMade {
  /// Keeps Core's answer.
  const BackupKeyMade({required this.fingerprint, required this.revision, required this.published});

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
BackupKeyMade backupMadeFrom(
  RecoveryScope scope, {
  required int code,
  required String lastLine,
  required String id,
  required String out,
}) {
  if (code != 0) {
    final typed = Identity.typedRefusal(lastLine);
    throw RecoveryRefused(backupKeyWords(code, typed?.reason, typed?.words), code: code, reason: typed?.reason);
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
  if (answer['id'] != id ||
      answered is! Map<String, dynamic> ||
      answered['kind'] != scope.backupKind ||
      answered['name'] != scope.name ||
      answer['file'] != out ||
      fingerprint is! String ||
      !fingerprint.startsWith('SHA256:') ||
      revision is! String ||
      published != !scope.inRegistry) {
    throw const RecoveryRefused(
      'Core answered another backup key than the one asked for. Nothing is published.',
      code: 0,
      reason: 'backup-only-own',
    );
  }
  return BackupKeyMade(
    fingerprint: fingerprint,
    revision: checkedRegistryRevision(revision),
    published: published as bool,
  );
}

/// Making one backup key for one list, under a request kept until its commit is pushed.
///
/// **One key per request**: a terminal that ended without a readable answer is retried under the same ID and base,
/// which Core answers without a second key; the new file's place is asked again and never kept.
class BackupKeyMaking {
  /// Constructor taking the list, the commit in force, Core's boundary and where the request is kept.
  BackupKeyMaking({required this.scope, required this.base, required this.core, required this.receipts, Random? random})
    : _random = random ?? Random.secure();

  /// The list the backup key stands in for its single admin.
  final RecoveryScope scope;

  /// The commit in force now; a kept request keeps its own.
  final String base;

  /// Core's boundary, for the registry checkout's prepare and push.
  final KeyRecoveryCore core;

  /// Where the request is kept.
  final RecoveryReceipts receipts;

  final Random _random;

  String get _key => 'backup-make/${scope.receiptKey}';

  ({String id, String base, String? revision})? get _kept {
    final kept = receipts.read(_key);
    final id = kept?['id'];
    final base = kept?['base'];
    final revision = kept?['revision'];
    if (kept == null || id is! String || base is! String || revision != null && revision is! String) return null;
    return (id: id, base: base, revision: revision as String?);
  }

  /// The commit Core made whose push is still owed, or null.
  String? get unpublished => _kept?.revision;

  /// Whether a request is kept, so the next attempt repeats it.
  bool get pending => _kept != null;

  /// Readies the making of the backup key into the new file [out] and answers the command its terminal runs.
  Future<List<String>> start(String out) async {
    final kept = _kept;
    if (kept?.revision != null) throw const RegistryRefusal('Push the backup key’s commit first.');
    if (kept == null && scope.inRegistry) await core.prepare(scope);
    final request = kept ?? (id: 'bk-${_newId()}', base: checkedRegistryRevision(base), revision: null);
    final command = backupMakeCommand(scope, out: out, id: request.id, base: request.base);
    await receipts.keep(_key, {'scope': scope.stored, 'id': request.id, 'base': request.base, 'revision': null});
    return command;
  }

  /// Takes what the terminal ended with; a registry commit is pushed from the app's checkout.
  Future<BackupKeyMade> ended({required int code, required String lastLine, required String out}) async {
    final kept = _kept;
    if (kept == null) throw const RegistryRefusal('No backup key is being made.');
    if (_terminalMadeNothing(code)) {
      await receipts.forget(_key);
      final typed = Identity.typedRefusal(lastLine);
      throw RecoveryRefused(backupKeyWords(code, typed?.reason, typed?.words), code: code, reason: typed?.reason);
    }
    final BackupKeyMade made;
    try {
      made = backupMadeFrom(scope, code: code, lastLine: lastLine, id: kept.id, out: out);
    } on RecoveryRefused catch (refused) {
      if (refused.reason == 'backup-only-own') await receipts.forget(_key);
      rethrow;
    }
    if (!made.published) {
      await receipts.keep(_key, {'scope': scope.stored, 'id': kept.id, 'base': kept.base, 'revision': made.revision});
      await publish();
    }
    await receipts.forget(_key);
    return BackupKeyMade(fingerprint: made.fingerprint, revision: made.revision, published: true);
  }

  /// Pushes the commit Core made in the registry checkout, once; a refused push keeps it for the next try.
  Future<void> publish() async {
    final kept = _kept;
    final revision = kept?.revision;
    if (kept == null || revision == null) return;
    await core.publish(scope, revision, base: kept.base);
    await receipts.forget(_key);
  }

  String _newId() => List.generate(8, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

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

/// Core's replacement verbs on this computer: `project access replace` and the registry's own filings.
class CliKeyRecoveryCore implements KeyRecoveryCore {
  /// Constructor taking the project adapters, the shared registry, the proven identity and a process runner.
  CliKeyRecoveryCore({
    required this.actor,
    this.project,
    this.registry,
    RunHere? run,
    Future<String> Function(String file)? readFile,
  }) : _run = run ?? runHere,
       _readFile = readFile ?? ((file) => File(file).readAsString());

  /// The person at this computer as Core proved them.
  final HostAdminIdentity? Function() actor;

  /// The project's Core adapter, which knows its folder and whether the person is its admin here.
  final ProjectAccessCoreAdapter? Function(String project)? project;

  /// The shared accepted registry, for host access files and owners.yml.
  final Registry? registry;

  final RunHere _run;
  final Future<String> Function(String file) _readFile;

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
  Future<RecoveryFiled> replace(RecoveryReview review, String id) async {
    if (!operationIdPattern.hasMatch(id)) throw const FormatException('Not a request ID.');
    final base = checkedRegistryRevision(review.base);
    if (review.scope.kind == RecoveryKind.project) {
      final adapter = project?.call(review.scope.name!);
      if (adapter == null) throw const RegistryRefusal('This project’s access is not connected to Core here.');
      final ran = await _run('porelo', [
        'project',
        'access',
        'replace',
        '--project',
        review.scope.name!,
        '--person',
        review.login,
        '--card',
        review.card,
        '--base',
        base,
        '--id',
        id,
        '--json',
      ], inDirectory: adapter.directory);
      if (ran.code != 0) {
        final typed = Identity.typedRefusal(ran.out);
        throw RecoveryRefused(typed?.words ?? _exitWords(ran.code), code: ran.code, reason: typed?.reason);
      }
      final answer = jsonDecode(ran.out);
      final revision = answer is Map<String, dynamic> ? answer['revision'] : null;
      if (revision is! String) throw const FormatException('Core did not answer the access revision.');
      return RecoveryFiled(revision: checkedRegistryRevision(revision), published: true);
    }
    final registry = _registry();
    final String content;
    final RegistryFilingKind kind;
    if (review.scope.kind == RecoveryKind.hostAccess) {
      final host = registry.hosts.where((host) => host.host == review.scope.name).firstOrNull;
      if (host == null) throw const RegistryRefusal('The registry lists no such host.');
      kind = RegistryFilingKind.hostAccess;
      content = hostAccessFileReplacing(
        host,
        person: review.login,
        oldFingerprint: review.oldFingerprint,
        newFingerprint: review.newFingerprint,
      );
    } else {
      kind = RegistryFilingKind.owners;
      final before = await _readFile(path.join(registry.checkout.folder, 'owners.yml'));
      content = ownersFileReplacing(
        before,
        review.scope,
        login: review.login,
        oldFingerprint: review.oldFingerprint,
        newKey: review.newKey,
      );
      checkOneKeyChanged(before, content);
    }
    // The person names the card the registry must trust, so Registry's trusted-card check applies.
    final filing = RegistryFiling(
      kind,
      host: kind == RegistryFilingKind.hostAccess ? review.scope.name : null,
      person: review.login,
      id: id,
      base: base,
      content: content,
    );
    if (registry.unavailable(filing) case final why?) {
      throw RecoveryRefused(why, code: 65, whoMay: registry.whoMay(filing));
    }
    await registry.checkout.prepareFiling();
    final RegistryFiled made;
    try {
      made = await registry.core.file(registry.checkout.folder, filing);
    } on RegistryRefusal catch (refused) {
      throw RecoveryRefused(refused.words, code: 65, whoMay: registry.whoMay(filing));
    }
    // Pushed by [publish], so a refused push keeps this commit for Retry instead of filing again.
    return RecoveryFiled(revision: checkedRegistryRevision(made.revision), published: false);
  }

  @override
  Future<void> prepare(RecoveryScope scope) async {
    if (scope.inRegistry) await _registry().checkout.prepareFiling();
  }

  @override
  Future<void> publish(RecoveryScope scope, String revision, {required String base}) async {
    if (!scope.inRegistry) return;
    final registry = this.registry;
    if (registry == null) throw const RegistryRefusal('The registry has not been read here yet.');
    await registry.checkout.publishMade(checkedRegistryRevision(revision), base: checkedRegistryRevision(base));
    await registry.refresh();
  }

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
  });

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
  List<RecoveryScope> get registryScopes => [
    if (registry.accepted != null) ...[
      const RecoveryScope.owner(),
      for (final host in registry.accepted!.hostAdmins.keys) RecoveryScope.hostAdmin(host),
    ],
  ];

  @override
  Future<RecoverySituation> situation(RecoveryScope scope) async {
    final accepted = registry.accepted;
    if (accepted == null || registry.problem != null) {
      throw const RegistryRefusal('Refresh the registry before replacing a key.');
    }
    final name = scope.name;
    RecoverySituation read({
      required Map<String, String> people,
      required String? base,
      required List<String> Function(String login) hostsOf,
      String? sole,
      bool backup = false,
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
        return read(
          people: {for (final person in view.access.developers.values) person.login: person.fingerprint},
          base: view.accessRevision,
          hostsOf: (_) => [view.host.name],
          sole: sole,
          backup: sole != null && (projectBackup?.call(name!, sole) ?? false),
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
