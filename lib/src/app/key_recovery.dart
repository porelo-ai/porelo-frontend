import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'identity.dart' show Identity, mayHaveMade, operationIdPattern;
import 'settings.dart';

/// The place a backup key stands in for: the organization's owner, or one host's admin.
@immutable
class BackupScope {
  /// The organization's owners.
  const BackupScope.organization() : host = null;

  /// The admins of [String host].
  const BackupScope.host(String this.host);

  /// The host, absent for the organization's owners.
  final String? host;

  /// Core's `identity backup-key` scope flags.
  List<String> get flags => switch (host) {
    final host? => ['--host', host],
    null => ['--organization'],
  };

  /// The scope `kind` Core's answer names, where it names one.
  String get kind => host == null ? 'organization' : 'host';

  /// The place in a person's words.
  String get words => switch (host) {
    final host? => 'the Machine Admins of machine $host',
    null => 'the organization’s owners',
  };

  /// Where a pending request for this place is kept.
  String get receiptKey => host == null ? kind : '$kind/$host';

  /// The scope's public record.
  Map<String, Object?> get stored => {'kind': kind, 'host': host};

  /// Reads a kept scope, refusing anything else.
  factory BackupScope.read(Object? value) {
    if (value is! Map) throw const FormatException('Invalid kept scope.');
    return switch ((value['kind'], value['host'])) {
      ('organization', null) => const BackupScope.organization(),
      ('host', final String host) => BackupScope.host(host),
      _ => throw const FormatException('Invalid kept scope.'),
    };
  }

  @override
  bool operator ==(Object other) => other is BackupScope && other.host == host;

  @override
  int get hashCode => host.hashCode;
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

/// Core refused a backup key, or its answer could not be taken; its words are what the person reads.
class BackupKeyRefused implements Exception {
  /// Keeps the words and Core's reason.
  const BackupKeyRefused(this.words, {this.reason});

  /// For a person.
  final String words;

  /// Core's reason, when it named one.
  final String? reason;

  @override
  String toString() => words;
}

/// What Core answered of a backup key: every write's fields, and what it says of the key where it says it.
@immutable
class BackupKeyDone {
  /// Keeps Core's answer.
  const BackupKeyDone({required this.revision, required this.again, this.fingerprint, this.file});

  /// The revision it rests on.
  final String? revision;

  /// Whether this request had made it already.
  final bool again;

  /// The backup key's fingerprint, where Core names it.
  final String? fingerprint;

  /// Where Core wrote the backup key's file, where it names it.
  final String? file;
}

/// What a request of [BackupKeyRequest] asks of Core.
enum BackupKeyUse {
  /// Make a new backup key into a new file: `--out`.
  make,

  /// Use the backup key to put a new card in place of the person's lost key: `--use` and `--card`.
  replace,
}

/// The command a terminal runs to make a backup key for [scope] into the new file [out], under [id] against [base].
List<String> backupMakeCommand(BackupScope scope, {required String out, required String id, required String base}) {
  if (out.trim().isEmpty) throw const FormatException('Choose where the backup key’s file goes.');
  return ['porelo', 'identity', 'backup-key', ...scope.flags, '--out', out, ..._write(id, base)];
}

/// The command a terminal runs to put the new card [card] in place of the lost key with the backup key in [file].
List<String> backupUseCommand(
  BackupScope scope, {
  required String file,
  required String card,
  required String id,
  required String base,
}) {
  if (file.trim().isEmpty) throw const FormatException('Choose the backup key’s file.');
  if (card.trim().isEmpty) throw const FormatException('No new card is kept on this computer.');
  return ['porelo', 'identity', 'backup-key', ...scope.flags, '--use', file, '--card', card, ..._write(id, base)];
}

List<String> _write(String id, String base) {
  if (!operationIdPattern.hasMatch(id)) throw const FormatException('Not a request ID.');
  return ['--base', checkedBase(base), '--id', id, '--json'];
}

/// [base] as a revision to hand a command, refusing what no revision can be.
String checkedBase(String base) {
  if (base.isEmpty) throw const FormatException('The organization has no revision read yet. Read it again.');
  if (base.startsWith('-') || base.contains(RegExp(r'\s'))) throw const FormatException('Not a revision.');
  return base;
}

/// The words of a refusal: Core's own, or what its exit code says.
String _refusalWords(int? code, String? words) {
  if (words != null && words.trim().isNotEmpty) return words.trim();
  return switch (code) {
    null || < 0 => 'The terminal was put away before Porelo answered, or its end could not be read.',
    64 => 'Porelo did not take this call. Nothing changed.',
    65 => 'Porelo refused it. Nothing changed.',
    66 => 'The backup file or what it names could not be read. Nothing changed.',
    69 => 'Porelo could not reach what it needs.',
    70 => 'Porelo failed inside.',
    77 => 'The vault is shut. Nothing changed.',
    78 => 'This computer has no Porelo organization. Nothing changed.',
    _ => 'Porelo ended with exit $code.',
  };
}

// After 69, 70 or a killed process the change may have been made; every other refusal made nothing.

/// One backup key asked for one place, under a request kept until Core answered.
///
/// **One key per request**: a terminal that ended without a readable answer is asked again under the same ID and base,
/// which Core answers without a second key; a backup file's place is asked again and never kept. A request is kept as
/// uncertain while its terminal runs; every refusal but 69 and 70 proves nothing was made, and drops it.
class BackupKeyRequest {
  /// Constructor taking the place, the use, the revision the page read and where the request is kept.
  BackupKeyRequest({required this.scope, required this.use, required this.base, required this.receipts, Random? random})
    : _random = random ?? Random.secure();

  /// The place the backup key stands in for.
  final BackupScope scope;

  /// Whether a key is made or used.
  final BackupKeyUse use;

  /// The revision the page read; a kept request keeps its own.
  final String base;

  /// Where the request is kept.
  final RecoveryReceipts receipts;

  final Random _random;

  String get _key => 'backup-${use.name}/${scope.receiptKey}';

  ({String id, String base, bool earlier})? get _kept {
    final kept = receipts.read(_key);
    if (kept == null) return null;
    final id = kept['id'];
    final base = kept['base'];
    final earlier = kept['earlier'];
    try {
      if (id is! String || !operationIdPattern.hasMatch(id) || base is! String || earlier is! bool) return null;
      if (BackupScope.read(kept['scope']) != scope) return null;
      return (id: id, base: checkedBase(base), earlier: earlier);
    } on FormatException {
      return null;
    }
  }

  /// Whether a request is kept, so the next attempt asks it again.
  bool get pending => _kept != null;

  /// The kept request's ID, or null.
  String? get requestId => _kept?.id;

  static final _running = Expando<Set<String>>('Backup keys asked for now');

  Set<String> get _runs => _running[receipts] ??= <String>{};

  /// Runs one attempt as [work]; a second for the same place is refused until it ended.
  Future<T> attempt<T>(Future<T> Function() work) async {
    if (!_runs.add(_key)) {
      throw BackupKeyRefused('A backup key for ${scope.words} is being asked for already; wait until it has ended.');
    }
    try {
      return await work();
    } finally {
      _runs.remove(_key);
    }
  }

  Future<void> _keepFor(String id, String base, {required bool earlier}) =>
      receipts.keep(_key, {'scope': scope.stored, 'id': id, 'base': base, 'earlier': earlier});

  /// Keeps the request and answers the command its terminal runs: on [file], with [card] for a replacement.
  Future<List<String>> start(String file, {String? card}) async {
    final kept = _kept;
    final id = kept?.id ?? 'bk-${_newId()}';
    final requestBase = kept?.base ?? checkedBase(base);
    final command = switch (use) {
      BackupKeyUse.make => backupMakeCommand(scope, out: file, id: id, base: requestBase),
      BackupKeyUse.replace => backupUseCommand(scope, file: file, card: card ?? '', id: id, base: requestBase),
    };
    // Kept before the terminal runs Core: an end never read back may have made the key.
    await _keepFor(id, requestBase, earlier: kept != null);
    return command;
  }

  /// Takes what the terminal ended with: whether its program [started], and Core's exit [code], none when its end was
  /// not seen; [file] is the one this attempt named.
  Future<BackupKeyDone> ended({
    required int? code,
    required String lastLine,
    required String file,
    bool started = true,
  }) async {
    final kept = _kept;
    if (kept == null) throw const BackupKeyRefused('No backup key is being asked for.');
    if (!started) {
      // A terminal that never opened leaves the request as it was before this attempt.
      if (!kept.earlier) await receipts.forget(_key);
      throw const BackupKeyRefused('The terminal did not start Porelo. Nothing changed.');
    }
    if (code != 0) {
      final typed = Identity.typedRefusal(lastLine);
      final words = _refusalWords(code, typed?.words);
      if (mayHaveMade(code)) {
        throw BackupKeyRefused('$words $_keptWords', reason: typed?.reason);
      }
      await receipts.forget(_key);
      throw BackupKeyRefused(words, reason: typed?.reason);
    }
    // Core ran: an answer that cannot be taken may stand for a made key, so its request stays.
    final BackupKeyDone done;
    try {
      done = _answer(lastLine, id: kept.id, file: kept.earlier ? null : file);
    } on FormatException catch (error) {
      throw BackupKeyRefused('${error.message} $_keptWords');
    }
    await receipts.forget(_key);
    return done;
  }

  static const _keptWords =
      'Porelo may have made it already, so its request is kept: ask again, and it answers what it made under that '
      'request.';

  /// Reads the answer field by field: every write's own, and what it names of the key is checked where it is named.
  BackupKeyDone _answer(String lastLine, {required String id, required String? file}) {
    final Object? decoded;
    try {
      decoded = jsonDecode(lastLine.trim());
    } on FormatException {
      throw const FormatException('Porelo gave an answer that could not be read.');
    }
    if (decoded is! Map<String, dynamic>) throw const FormatException('Porelo gave an answer that could not be read.');
    if (decoded['id'] != id) throw const FormatException('Porelo answered another request than this one.');
    final answered = decoded['scope'];
    if (answered != null &&
        (answered is! Map<String, dynamic> ||
            answered['kind'] != scope.kind ||
            (scope.host != null && answered['name'] != scope.host))) {
      throw FormatException('Porelo changed another place than ${scope.words}.');
    }
    final revision = decoded['revision'];
    final fingerprint = decoded['fingerprint'];
    final written = decoded['file'];
    if (revision != null && revision is! String ||
        fingerprint != null && fingerprint is! String ||
        written != null && written is! String) {
      throw const FormatException('Porelo gave an answer that could not be read.');
    }
    if (use == BackupKeyUse.make && file != null && written != null && written != file) {
      throw FormatException('Porelo wrote the key to $written, not $file.');
    }
    return BackupKeyDone(
      revision: revision as String?,
      again: decoded['again'] == true,
      fingerprint: fingerprint as String?,
      file: written as String?,
    );
  }

  String _newId() => List.generate(8, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}
