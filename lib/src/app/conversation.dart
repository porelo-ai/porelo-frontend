import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'fleet_backend.dart';
import 'homeserver_forwards.dart';
import 'login_forward.dart';
import 'machines.dart';

/// A project's conversation as a person sees it: where it is, who has joined, and joining it.
///
/// **The login is answered once and kept nowhere**: it lives in [joined] while this is open, and
/// goes with it. The machine keeps no copy either, so a second look is a new password (reset).
class ProjectConversation extends ChangeNotifier {
  /// Constructor taking the machine, where it is reached, and the project.
  ProjectConversation(this._backend, this.machine, this.project, {this._forwards}) {
    _forwards?.addListener(_forwardsChanged);
  }

  /// Where a joined homeserver is held forwarded while the window runs; without it, only while this
  /// is open.
  final HomeserverForwards? _forwards;

  final FleetBackend _backend;

  /// The machine the conversation's homeserver is on, when it is the account's own.
  final Machine machine;

  /// The project whose conversation this is.
  final Project project;

  /// Who has joined, or null before the machine answered.
  List<MessageMember>? members;

  /// The answered join only while its homeserver is reachable; never kept beyond this dialog.
  MessagesJoined? get joined {
    final answer = _joined;
    if (answer != null && answer.loopback && machine.host.isNotEmpty && forwarded != answer.port) return null;
    return answer;
  }

  MessagesJoined? _joined;

  MessagesJoined? _pendingJoin;
  String? _pendingPerson;

  /// The person a join was refused for because they have an account already, or null.
  String? alreadyJoined;

  /// Why the last thing asked did not happen, in words, or null.
  String? problem;

  /// Why the homeserver's port could not be forwarded here, or null.
  String? forwardProblem;

  /// The port forwarded here, or null: kept by [HomeserverForwards] while the window runs, so a dialog
  /// opened again later says it too.
  int? get forwarded => _forwarded ?? _forwards?.portOf(machine, project.name);
  int? _forwarded;

  /// Whether something is being asked of the machine right now.
  bool busy = false;

  HeldForward? _forward;
  bool _gone = false;

  /// Asks who has joined.
  Future<void> load() => _asking(() async {
    members = await _backend.messageMembers(project.name);
  });

  /// Clears the previous name's refusal and password-reset offer when the name changes.
  void personChanged() {
    problem = null;
    alreadyJoined = null;
    _notify();
  }

  /// Lets [person] in, or gives their account a new password with [reset].
  Future<void> join(String person, {bool reset = false}) => _asking(() async {
    alreadyJoined = null;
    _joined = null;
    forwardProblem = null;
    if (_pendingPerson != person || reset) _pendingJoin = null;
    final answer = _pendingJoin ?? await _backend.joinMessages(project.name, person, reset: reset);
    if (_gone) return;
    _pendingJoin = answer;
    _pendingPerson = person;
    await _forwardTheHomeserver(answer);
    if (_gone) return;
    if (forwardProblem != null) {
      problem = forwardProblem;
      return;
    }
    _joined = answer;
    members = await _backend.messageMembers(project.name);
  });

  /// Where the homeserver is the machine's own loopback, a client on this computer reaches it only
  /// through a forward of the same port, held while this is open.
  Future<void> _forwardTheHomeserver(MessagesJoined answer) async {
    final port = answer.port;
    // The homeserver's SSH destination does not depend on who forwards the daemon socket.
    if (!answer.loopback || machine.host.isEmpty) return;
    if (port == null || port < 1024 || port > 65535) {
      forwardProblem = 'The machine named port $port for its homeserver, which is not one to forward.';
      return;
    }
    final forwards = _forwards;
    if (forwards != null) {
      // Held beyond this dialog: a Matrix client keeps its server when the dialog closes.
      await forwards.hold(machine, project.name, port);
      forwardProblem = forwards.problemOf(machine, project.name);
      if (forwardProblem == null && forwards.portOf(machine, project.name) != port) {
        forwardProblem = 'The homeserver forward did not come up.';
      }
      return;
    }
    if (_forwarded == port) return;
    try {
      await _forward?.close();
      _forward = null;
      _forwarded = null;
      final held = await raiseForward(machine, port);
      if (_gone) {
        await held.close();
        return;
      }
      _forward = held;
      _forwarded = port;
    } on ForwardRefused catch (refused) {
      forwardProblem = refused.words;
    } on Exception catch (error) {
      forwardProblem = 'The homeserver could not be forwarded: $error';
    }
  }

  Future<void> _asking(Future<void> Function() action) async {
    busy = true;
    problem = null;
    _notify();
    try {
      await action();
    } on FeatureNotSupported {
      problem = 'This machine cannot let a person into a project’s conversation.';
    } on VarlinkException catch (refusal) {
      final said = refusal.parameters;
      switch (refusal.simpleName) {
        case 'MemberExists':
          alreadyJoined = '${said['person'] ?? ''}';
          problem =
              '${said['person'] ?? 'They'} has joined already, as ${said['user'] ?? 'an account'}. '
              'A new password can be given; the one they have stops working.';
        case 'NoConversation':
          problem =
              '${project.name} has no conversation: none of its peers is reached through a transport '
              'of its own.';
        case 'ConversationRefused':
          problem = 'The transport refused it: ${said['message'] ?? ''}';
        case 'NoSuchProject':
          problem = 'This machine does not follow ${project.name}.';
        default:
          problem = 'The machine refused it: ${said['message'] ?? refusal.simpleName}.';
      }
    } on VarlinkDisconnected catch (ex) {
      problem = 'Lost contact with the machine: ${ex.message}';
    } finally {
      busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_gone) notifyListeners();
  }

  void _forwardsChanged() {
    final previous = forwardProblem;
    forwardProblem = _forwards?.problemOf(machine, project.name);
    if (_joined != null && joined == null) {
      problem = forwardProblem ?? 'The homeserver forward did not come up.';
    } else if (joined != null && problem == previous) {
      problem = null;
    }
    _notify();
  }

  @override
  void dispose() {
    _gone = true;
    // The login goes with the dialog: nothing of it is kept.
    _forwards?.removeListener(_forwardsChanged);
    _joined = null;
    _pendingJoin = null;
    _pendingPerson = null;
    final held = _forward;
    _forward = null;
    unawaited(held?.close());
    super.dispose();
  }
}
