import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:porelo_host/porelo_host.dart' show forgeAddress;

import '../client/models.dart' show MachineForges;
import '../client/porelo_client.dart' show FeatureNotSupported;
import '../wire/limit_factors.dart';
import '../wire/varlink_exception.dart';
import 'forge_connection.dart';
import 'fleet_backend.dart' show KnowsForges;
import 'quiet_after_dispose.dart';
import 'window_log.dart';

/// A watched machine whose list of work was read, as [ForgeRecords] reaches it.
typedef ForgeMachine = ({String name, Object backend});

/// Makes every forge set up under My forges known to each watched machine, with the forge adapter of its kind and how
/// its comments are read: once a forge is set up, signed in to or its reading chosen, and once a machine watched later
/// has its list of work read. Only the owner account reaches a machine's socket, so every watched machine is the
/// person's own.
class ForgeRecords extends ChangeNotifier with QuietAfterDispose {
  /// Takes the person's forges and the watched machines whose list of work was read.
  ForgeRecords({required this.forges, required this.machines, this.now = DateTime.now});

  /// The person's forges.
  final ForgeConnection forges;

  /// The watched machines whose list of work was read.
  final Iterable<ForgeMachine> Function() machines;

  /// The time now.
  final DateTime Function() now;

  /// How long a machine not told everything is left before it is asked again.
  static const _again = Duration(minutes: 1);

  /// The connection each machine was told the forges through, and what it was told: a machine answering through
  /// another connection, one restarted or upgraded among them, is told again.
  final _told = <String, (Object, String)>{};

  /// When a machine last could not be told everything, so it is asked again only after [_again].
  final _notDone = <String, DateTime>{};

  /// The machines a call goes to now, so none is asked twice at once.
  final _asking = <String>{};

  bool _gone = false;

  /// Why a forge is not known to a machine, by machine and host; empty where every one is.
  Map<(String, String), String> get problems => Map.unmodifiable(_problems);
  final _problems = <(String, String), String>{};

  @override
  void dispose() {
    _gone = true;
    super.dispose();
  }

  /// Looks at every watched machine and tells each the forges it was not told yet.
  void look() {
    if (_gone) return;
    final forgesNow = _forgesOf(forges.entries);
    final told = _record(forgesNow);
    final watched = machines().toList();
    final before = _problems.length;
    // What is said only of a machine still watched and a forge still set up.
    _problems.removeWhere(
      (key, _) => !watched.any((each) => each.name == key.$1) || !forgesNow.any((each) => each.$1 == key.$2),
    );
    if (_problems.length != before) notifyListeners();
    for (final machine in watched) {
      final backend = machine.backend;
      if (backend is! KnowsForges) continue;
      if (_told[machine.name] case (final through, final record) when identical(through, backend) && record == told) {
        continue;
      }
      if (_notDone[machine.name] case final at? when now().difference(at) < pollEvery(_again)) continue;
      if (!_asking.add(machine.name)) continue;
      unawaited(
        _tell(machine.name, backend, forgesNow, told).whenComplete(() {
          _asking.remove(machine.name);
          // The forges may have changed while it was asked: what it was not told yet goes now.
          look();
        }),
      );
    }
  }

  Future<void> _tell(
    String machine,
    KnowsForges backend,
    List<(String, String, String?)> forgesNow,
    String told,
  ) async {
    final MachineForges known;
    try {
      known = await backend.forges();
    } on FeatureNotSupported {
      _older(machine, backend, told);
      return;
    } on VarlinkException catch (refusal) {
      // The machine answered but cannot read what it keeps: said for each forge, and asked again later.
      _notTold(machine, refusal, forgesNow, (host) => _refusalWords(machine, host, refusal));
      return;
    } on Object catch (error) {
      _notTold(
        machine,
        error,
        forgesNow,
        (host) => '$machine was not reached yet; it is told about $host once it answers.',
      );
      return;
    }
    if (_gone) return;
    _problems.removeWhere((key, _) => key.$1 == machine);
    var done = true;
    for (final (host, kind, chosen) in forgesNow) {
      if (!known.adapters.contains(kind)) {
        _problems[(machine, host)] =
            '$machine has no forge adapter for $kind installed, so its tasks cannot reach $host.';
        done = false;
        continue;
      }
      final had = known.forges.where((each) => each.host == host).firstOrNull;
      // Kept trusted where the machine was told so before: only the person's own choice makes it stricter.
      final trusted = chosen == 'TRUSTED' || chosen == null && (had?.trusted ?? false);
      if (had != null && had.adapter == kind && had.unreadable == null && had.trusted == trusted) continue;
      try {
        await backend.forgeSet(host, kind, comments: trusted ? 'TRUSTED' : null);
      } on FeatureNotSupported {
        _older(machine, backend, told);
        return;
      } on VarlinkException catch (refusal) {
        _problems[(machine, host)] = _refusalWords(machine, host, refusal);
        done = false;
      } on Object catch (error) {
        _notTold(machine, error, [
          (host, kind, chosen),
        ], (host) => '$machine was not reached yet; it is told about $host once it answers.');
        return;
      }
      if (_gone) return;
    }
    if (done) {
      _told[machine] = (backend, told);
      _notDone.remove(machine);
    } else {
      _notDone[machine] = now();
    }
    notifyListeners();
  }

  /// A Porelo older than its forges keeps none: nothing to tell it through this connection, and nothing wrong.
  void _older(String machine, KnowsForges backend, String told) {
    if (_gone) return;
    _told[machine] = (backend, told);
    _notDone.remove(machine);
    _problems.removeWhere((key, _) => key.$1 == machine);
    notifyListeners();
  }

  /// A machine not reached, or not answering as a machine should, is said in the log and asked again later.
  void _notTold(
    String machine,
    Object error,
    List<(String, String, String?)> about,
    String Function(String host) words,
  ) {
    if (_gone) return;
    _notDone[machine] = now();
    for (final (host, _, _) in about) {
      _problems[(machine, host)] = words(host);
    }
    windowLog.warn('The forges set up here could not be made known to $machine: $error', machine: machine);
    notifyListeners();
  }

  static String _refusalWords(String machine, String host, VarlinkException refusal) => switch (refusal) {
    VarlinkException(simpleName: 'AdapterNotInstalled', :final parameters) =>
      '$machine has no forge adapter ${parameters['adapter'] ?? ''} installed, so its tasks cannot reach $host.',
    VarlinkException(simpleName: 'ForgeFileUnreadable', :final parameters) =>
      '$machine cannot read the forges it keeps${parameters['reason'] is String ? ': ${parameters['reason']}' : ''}.',
    VarlinkException(simpleName: 'InvalidParameter') => '$machine does not take $host as a forge host.',
    _ => '$machine refused to know $host as a forge: $refusal',
  };

  /// The host, kind and chosen reading of each forge a machine is told, once per host: a forge a machine's tunnel
  /// serves, or one with no host, is none. Where two forges share a host, its comments are trusted only where one
  /// chose that and none chose extended.
  static List<(String, String, String?)> _forgesOf(List<ForgeEntry> entries) {
    final byHost = <String, (String, String, String?)>{};
    for (final entry in entries) {
      if (entry.isHost) continue;
      final String host;
      try {
        host = forgeAddress(entry.address);
      } on FormatException {
        continue;
      }
      final chosen = switch ((byHost[host]?.$3, entry.comments)) {
        ('EXTENDED', _) || (_, 'EXTENDED') => 'EXTENDED',
        ('TRUSTED', _) || (_, 'TRUSTED') => 'TRUSTED',
        _ => null,
      };
      byHost[host] = (host, byHost[host]?.$2 ?? entry.kind, chosen);
    }
    return byHost.values.toList();
  }

  static String _record(List<(String, String, String?)> forges) =>
      forges.map((each) => '${each.$1} ${each.$2} ${each.$3}').join('\n');
}
