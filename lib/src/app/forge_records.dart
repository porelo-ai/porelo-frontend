import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:porelo_host/porelo_host.dart' show forgeAddress;

import '../client/models.dart' show ForgeInstance, MachineForges;
import '../client/porelo_client.dart' show FeatureNotSupported;
import '../wire/limit_factors.dart';
import '../wire/varlink_exception.dart';
import 'forge_connection.dart';
import 'fleet_backend.dart' show KnowsForges;
import 'quiet_after_dispose.dart';
import 'window_log.dart';

/// A watched machine whose list of work was read, as [ForgeRecords] reaches it.
typedef ForgeMachine = ({String name, Object backend});

/// How a watched machine's own forges stand: what was read of them, or why nothing was.
enum KeptStanding {
  /// The machine answered; its forges are those of the answer, which may be none.
  read,

  /// The machine answered that it cannot read what it keeps, in its words.
  unreadable,

  /// The machine's Porelo is older than its forges: it keeps none, and cannot list them.
  older,

  /// Nothing was read yet, or the machine could not be reached.
  notReached,
}

/// What a watched machine's `Forges` last answered, and how it stands.
@immutable
class KeptForges {
  /// Constructor taking the standing, the answer where it was read, and the words where it was not.
  const KeptForges(this.standing, {this.answer, this.words});

  /// How it stands.
  final KeptStanding standing;

  /// The answer, only where [standing] is [KeptStanding.read].
  final MachineForges? answer;

  /// The machine's words or the window's, where nothing was read.
  final String? words;
}

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

  /// What each watched machine last answered, by name; a machine absent here was not asked yet.
  Map<String, KeptForges> get kept => Map.unmodifiable(_kept);
  final _kept = <String, KeptForges>{};

  void _keep(String machine, KeptForges now) {
    final before = _kept[machine];
    _kept[machine] = now;
    if (before == null || before.standing != now.standing || before.words != now.words || before.answer != now.answer) {
      notifyListeners();
    }
  }

  /// Why a forge is not known to a machine, by machine and host; empty where every one is.
  Map<(String, String), String> get problems => Map.unmodifiable(_problems);
  final _problems = <(String, String), String>{};

  @override
  void dispose() {
    _gone = true;
    super.dispose();
  }

  /// Asks every watched machine anew, so what a machine keeps that was set up on it shows after a refresh.
  void askAgain() {
    if (_gone) return;
    _told.clear();
    _notDone.clear();
    look();
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
    // What is kept only of a machine still watched.
    final gone = _kept.keys.where((name) => !watched.any((each) => each.name == name)).toList();
    for (final name in gone) {
      _kept.remove(name);
    }
    if (gone.isNotEmpty) notifyListeners();
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
      if (!_gone) _keep(machine, KeptForges(KeptStanding.unreadable, words: _standingWords(machine, refusal)));
      // The machine answered but cannot read what it keeps: said for each forge, and asked again later.
      _notTold(machine, refusal, forgesNow, (host) => _refusalWords(machine, host, refusal));
      return;
    } on Object catch (error) {
      if (!_gone) _keep(machine, KeptForges(KeptStanding.notReached, words: '$machine was not reached: $error'));
      _notTold(
        machine,
        error,
        forgesNow,
        (host) => '$machine was not reached yet; it is told about $host once it answers.',
      );
      return;
    }
    if (_gone) return;
    _keep(machine, KeptForges(KeptStanding.read, answer: known));
    _problems.removeWhere((key, _) => key.$1 == machine);
    var done = true;
    var changed = false;
    for (final (host, kind, chosen) in forgesNow) {
      if (!known.adapters.contains(kind)) {
        _problems[(machine, host)] =
            '$machine has no forge adapter for $kind installed, so its tasks cannot reach $host.';
        done = false;
        continue;
      }
      final had = known.forges.where((each) => each.host.toLowerCase() == host.toLowerCase()).firstOrNull;
      // Kept trusted where the machine was told so before: only the person's own choice makes it stricter.
      final trusted = chosen == 'TRUSTED' || chosen == null && (had?.trusted ?? false);
      if (had != null && had.adapter == kind && had.unreadable == null && had.trusted == trusted) continue;
      try {
        await backend.forgeSet(host, kind, comments: trusted ? 'TRUSTED' : null);
        changed = true;
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
    // What the machine keeps now includes what it was just told, so the page names it as kept there.
    if (changed) {
      try {
        final after = await backend.forges();
        if (!_gone) _keep(machine, KeptForges(KeptStanding.read, answer: after));
      } on VarlinkException catch (refusal) {
        // The answer before is out of date now, so it no longer stands as read; the machine is asked again.
        if (!_gone) _keep(machine, KeptForges(KeptStanding.unreadable, words: _standingWords(machine, refusal)));
        done = false;
      } on Object catch (error) {
        if (!_gone) _keep(machine, KeptForges(KeptStanding.notReached, words: '$machine was not reached: $error'));
        done = false;
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
    _keep(machine, const KeptForges(KeptStanding.older));
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

  static String _standingWords(String machine, VarlinkException refusal) => switch (refusal) {
    VarlinkException(simpleName: 'ForgeFileUnreadable', :final parameters) =>
      '$machine cannot read the forges it keeps${parameters['reason'] is String ? ': ${parameters['reason']}' : ''}.',
    _ => '$machine refused to list its forges: $refusal',
  };

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

/// One machine's own forge, as it keeps it.
@immutable
class KeptOn {
  /// Constructor taking the machine and the forge it keeps.
  const KeptOn(this.machine, this.forge);

  /// The machine's name.
  final String machine;

  /// What the machine keeps of the forge.
  final ForgeInstance forge;

  /// How the machine keeps it, in words: the adapter, and how its comments are read or why it cannot be read.
  String get words => switch (forge.unreadable) {
    final reason? => '$machine: ${forge.adapter}, unreadable: $reason',
    null => '$machine: ${forge.adapter}, comments ${forge.trusted ? 'trusted' : 'extended'}',
  };
}

/// The host of a forge set up here, as a machine keeps it; null where its address names none.
String? keptHostOf(ForgeEntry entry) {
  if (entry.isHost) return null;
  try {
    return forgeAddress(entry.address).toLowerCase();
  } on FormatException {
    return null;
  }
}

/// The forges the machines named in [order] keep, by host in the order first met: only a machine whose answer was
/// read has any here; one not read, unreadable or older keeps none that are known.
Map<String, List<KeptOn>> forgesKeptByMachines(Map<String, KeptForges> kept, Iterable<String> order) {
  final byHost = <String, List<KeptOn>>{};
  for (final name in order) {
    final keeps = kept[name];
    if (keeps == null || keeps.standing != KeptStanding.read) continue;
    for (final forge in keeps.answer?.forges ?? const <ForgeInstance>[]) {
      byHost.putIfAbsent(forge.host.toLowerCase(), () => <KeptOn>[]).add(KeptOn(name, forge));
    }
  }
  return byHost;
}

/// The hosts of [listed], lowercased: a forge set up here, or one only a machine declares a credential for.
Set<String> listedHosts(List<ListedForge> listed) => {
  for (final each in listed)
    if (each.entry == null) each.address.toLowerCase() else ?keptHostOf(each.entry!),
};

/// How many forges machines keep that are not already listed in [listed]: the machines' own, counted apart.
int forgesOnlyMachinesKeep(Map<String, List<KeptOn>> byHost, List<ListedForge> listed) {
  final own = listedHosts(listed);
  return byHost.keys.where((host) => !own.contains(host)).length;
}

/// The watched machines among [watched] whose forges are not known: not asked yet, not reached, unreadable or older.
List<String> machinesNotRead(Map<String, KeptForges> kept, Iterable<String> watched) => [
  for (final name in watched)
    if (kept[name]?.standing != KeptStanding.read) name,
];
