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
  ProjectConversation(this._backend, this.machine, this.project, {this._forwards});

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

  /// What the last join answered, while this is open; never kept beyond it.
  MessagesJoined? joined;

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

  /// Lets [person] in, or gives their account a new password with [reset].
  Future<void> join(String person, {bool reset = false}) => _asking(() async {
        alreadyJoined = null;
        final answer = await _backend.joinMessages(project.name, person, reset: reset);
        joined = answer;
        members = await _backend.messageMembers(project.name);
        await _forwardTheHomeserver(answer);
      });

  /// Where the homeserver is the machine's own loopback, a client on this computer reaches it only
  /// through a forward of the same port, held while this is open.
  Future<void> _forwardTheHomeserver(MessagesJoined answer) async {
    final port = answer.port;
    // A machine whose socket is this computer's own needs nothing: its loopback is this one's.
    if (!answer.loopback || port == null || forwarded != null || !machine.needsATunnel) return;
    if (port < 1024 || port > 65535) {
      forwardProblem = 'The machine named port $port for its homeserver, which is not one to forward.';
      return;
    }
    final forwards = _forwards;
    if (forwards != null) {
      // Held beyond this dialog: a Matrix client keeps its server when the dialog closes.
      await forwards.hold(machine, project.name, port);
      forwardProblem = forwards.problemOf(machine, project.name);
      return;
    }
    try {
      final held = await raiseForward(machine, port);
      if (_gone) {
        await held.close();
        return;
      }
      _forward = held;
      _forwarded = port;
    } on ForwardRefused catch (refused) {
      forwardProblem = refused.words;
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
          problem = '${said['person'] ?? 'They'} has joined already, as ${said['user'] ?? 'an account'}. '
              'A new password can be given; the one they have stops working.';
        case 'NoConversation':
          problem = '${project.name} has no conversation: none of its peers is reached through a transport '
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

  @override
  void dispose() {
    _gone = true;
    // The login goes with the dialog: nothing of it is kept.
    joined = null;
    final held = _forward;
    _forward = null;
    unawaited(held?.close());
    super.dispose();
  }
}
