import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'fleet_backend.dart';

/// The messages on one machine that wait for a person, as the machine lists them.
///
/// **Asked of the machine, never assembled from the stream.** `Talk` replays nothing, so a list
/// built from it would miss everything held before this interface connected and show *nothing
/// needs you* while messages wait. The stream only says when to ask again.
class Mailboxes extends ChangeNotifier {
  List<HeldMessage> _held = const <HeldMessage>[];
  StreamSubscription<TalkEvent>? _listening;
  FleetBackend? _backend;
  bool _disposed = false;
  bool _asking = false;
  bool _askAgain = false;

  /// Why the list could not be asked for, or null while it can.
  String? problem;

  /// Whether this machine can list them at all. False for a daemon older than `Held`, which is said
  /// rather than shown as an empty list.
  bool supported = true;

  final List<TalkEvent> _events = <TalkEvent>[];

  /// What happened to messages since this interface connected, oldest first. `Talk` replays
  /// nothing, so this is never the whole history, and is not said to be.
  List<TalkEvent> get events => List<TalkEvent>.unmodifiable(_events);

  /// What happened to the messages of any of [tasks] since this interface connected, newest first.
  List<TalkEvent> eventsOfAny(Set<String> tasks) => <TalkEvent>[
    for (final each in _events.reversed)
      if (tasks.contains(each.task)) each,
  ];

  /// How many messages between [task] and [peer] wait for a person's decision right now.
  int waitingWith(String task, String peer) =>
      _held.where((each) => each.waits && each.task == task && each.peer == peer).length;

  /// What happened to one task's messages since this interface connected, newest first.
  List<TalkEvent> eventsOf(String task) => <TalkEvent>[
    for (final each in _events.reversed)
      if (each.task == task) each,
  ];

  /// Everything listed, including what is only there to be seen: refused for good, or unchecked.
  List<HeldMessage> get held => _held;

  /// What still waits for a decision, oldest first.
  List<HeldMessage> get waiting => <HeldMessage>[
    for (final each in _held)
      if (each.waits) each,
  ]..sort((a, b) => a.at.compareTo(b.at));

  /// Starts watching. Safe to call again; it replaces what was watching before.
  void watch(FleetBackend backend) {
    _backend = backend;
    _listening?.cancel();
    unawaited(refresh());
    _listening = backend.talk().listen(
      (event) {
        _events.add(event);
        // Bounded: a busy machine streams all day, and what a person looks back at is the recent part.
        if (_events.length > 500) _events.removeAt(0);
        _notify();
        unawaited(refresh());
      },
      // A daemon without Talk still lists what is held; it is only asked less often.
      onError: (Object _) {},
    );
  }

  /// Asks the machine what is held now. Calls that arrive while one is out are folded into one more.
  Future<void> refresh() async {
    final backend = _backend;
    if (backend == null) return;
    if (_asking) {
      _askAgain = true;
      return;
    }
    _asking = true;
    try {
      do {
        _askAgain = false;
        _held = await backend.messagesHeld();
        supported = true;
        problem = null;
      } while (_askAgain && !_disposed);
    } on FeatureNotSupported {
      supported = false;
      problem = 'This machine cannot list the messages held for a person.';
      _held = const <HeldMessage>[];
    } on VarlinkException catch (refusal) {
      problem = 'The machine refused to list them: ${refusal.simpleName}.';
    } on VarlinkDisconnected catch (ex) {
      problem = 'Lost contact while asking: ${ex.message}';
    } finally {
      _asking = false;
    }
    _notify();
  }

  /// Reads one in full.
  Future<HeldMessageRead> read(FleetBackend backend, HeldMessage message) =>
      backend.readHeld(message.task, message.handle);

  /// Decides about exactly [read]: named by the file that was read, so there is no moment in which
  /// the decision and what was on screen could be two different messages.
  Future<MessageRelease> decide(
    FleetBackend backend,
    HeldMessageRead read,
    String task, {
    required bool refuse,
    String reason = '',
  }) async {
    final done = await backend.release(
      task,
      read.message.isNotEmpty ? read.message : read.id,
      refuse: refuse,
      reason: reason,
    );
    await refresh();
    return done;
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _listening?.cancel();
    super.dispose();
  }
}
