import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'login_forward.dart';
import 'machines.dart';
import 'settings.dart';

/// The homeservers a person joined from this computer, **forwarded while the window runs**, not
/// only while the Messages dialog is open (walk 10: nheko lost its server the moment
/// the dialog closed, and two messages went nowhere).
///
/// Each is kept in [Settings], so the window raises it again when it starts. One that drops is
/// raised again on the next look, and one that cannot be says why where a person looks.
class HomeserverForwards extends ChangeNotifier {
  /// Constructor taking where joined homeservers are kept, how a forward is raised, and how a port
  /// is tried.
  HomeserverForwards(
    this._settings, {
    RaiseLoginForward? raise,
    Future<bool> Function(int port)? answers,
    this.lookEvery = const Duration(seconds: 30),
  }) : _raise = raise ?? raiseForward,
       _answers = answers ?? answering;

  /// Whether a forwarded port answers here: a connection to it, as a Matrix client makes one. Injectable,
  /// as [raiseLoginForward] is, so the frame is judged without a port.
  static Future<bool> Function(int port) answering = _answersHere;

  final Settings _settings;
  final RaiseLoginForward _raise;
  final Future<bool> Function(int port) _answers;

  /// How often each held forward is tried, and raised again where it dropped.
  final Duration lookEvery;

  final Map<String, HeldForward> _held = <String, HeldForward>{};
  final Map<String, String> _problems = <String, String>{};
  Timer? _looking;
  bool _disposed = false;

  static String _key(String machine, String project) => '$machine/$project';

  /// The port at which a Matrix client here reaches [project]'s homeserver on [machine], or null
  /// where it is not forwarded.
  int? portOf(Machine machine, String project) {
    final key = _key(machine.name, project);
    if (!_held.containsKey(key)) return null;
    return _settings.homeservers
        .where((each) => each.machine == machine.name && each.project == project)
        .firstOrNull
        ?.port;
  }

  /// Every homeserver that cannot be forwarded now, with why: said under *Needs you*, since a Matrix
  /// client here cannot reach it until it is.
  List<({String machine, String project, String words})> get refused =>
      <({String machine, String project, String words})>[
        for (final each in _settings.homeservers)
          if (_problems[_key(each.machine, each.project)] case final words?)
            (machine: each.machine, project: each.project, words: words),
      ];

  /// Tries [project]'s homeserver on [machine] again, as remembered.
  Future<void> retry(Machine machine, String project) async {
    final kept = _settings.homeservers
        .where((each) => each.machine == machine.name && each.project == project)
        .firstOrNull;
    if (kept != null) await _raiseFor(machine, project, kept.port);
  }

  /// Why [project]'s homeserver on [machine] is not forwarded, or null.
  String? problemOf(Machine machine, String project) => _problems[_key(machine.name, project)];

  /// Holds [project]'s homeserver on [machine] forwarded on [port] from now on, and remembers it.
  Future<void> hold(Machine machine, String project, int port) async {
    await _settings.rememberHomeserver(machine.name, project, port);
    await _raiseFor(machine, project, port);
  }

  /// Raises again what was joined before, for the machines in [machines], and keeps looking.
  Future<void> restore(Machines machines) async {
    for (final each in _settings.homeservers) {
      final machine = machines.all.where((m) => m.name == each.machine).firstOrNull;
      if (machine != null) await _raiseFor(machine, each.project, each.port);
    }
    _looking?.cancel();
    _looking = Timer.periodic(lookEvery, (_) => unawaited(_look(machines)));
  }

  Future<void> _look(Machines machines) async {
    for (final each in _settings.homeservers) {
      final machine = machines.all.where((m) => m.name == each.machine).firstOrNull;
      if (machine == null) continue;
      final key = _key(each.machine, each.project);
      if (_held.containsKey(key) && await _answers(each.port)) continue;
      await _held.remove(key)?.close();
      await _raiseFor(machine, each.project, each.port);
    }
  }

  Future<void> _raiseFor(Machine machine, String project, int port) async {
    final key = _key(machine.name, project);
    if (_held.containsKey(key) && await _answers(port)) return;
    await _held.remove(key)?.close();
    try {
      _held[key] = await _raise(machine, port);
      _problems.remove(key);
    } on ForwardRefused catch (refused) {
      _problems[key] = refused.words;
    } on Object catch (error) {
      _problems[key] = 'The homeserver could not be forwarded: $error';
    }
    if (!_disposed) notifyListeners();
  }

  static Future<bool> _answersHere(int port) async {
    try {
      final socket = await Socket.connect(InternetAddress.loopbackIPv4, port, timeout: const Duration(seconds: 2));
      socket.destroy();
      return true;
    } on SocketException {
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _looking?.cancel();
    for (final each in _held.values) {
      unawaited(each.close());
    }
    _held.clear();
    super.dispose();
  }
}
