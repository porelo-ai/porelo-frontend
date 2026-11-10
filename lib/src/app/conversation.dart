import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'fleet_backend.dart';
import 'homeserver_forwards.dart';
import 'login_forward.dart';
import 'machines.dart';
import 'organization_source.dart';
import 'settings.dart';

/// A project's conversation as a person sees it: where it is, who has joined, and joining it.
///
/// **The login is answered once and kept nowhere**: it lives in [joined] while this is open, and
/// goes with it. The machine keeps no copy either, so a second look is a new password (reset).
class ProjectConversation extends ChangeNotifier {
  /// Constructor taking the machine, where it is reached, and the project.
  ProjectConversation(
    this._backend,
    this.machine,
    this.project, {
    required Settings settings,
    this._forwards,
    this._admission,
    this._admissionChanges,
  }) : _settings = settings,
       _person = settings.messagePerson(machine.name, project.name) {
    _forwards?.addListener(_forwardsChanged);
    _admissionChanges?.addListener(_notify);
  }

  final RoomAdmission Function()? _admission;
  final Listenable? _admissionChanges;

  /// Whom the room takes, as the organization says now: any name where the project is the machine's own.
  RoomAdmission get admission => _admission?.call() ?? const AnyName();

  /// The homeserver a person's Element signs in to where [machine] is a host running its own: there it manages
  /// its people itself, so a person signs in with SSO and is never let in by a join here. Null elsewhere.
  String? get hostHomeserver => machine.hostCard?.matrixUrl;

  /// The login a person signs in as at the host's homeserver: the one the host admitted here.
  String? get hostLogin => machine.hostCard?.login;

  /// Where a joined homeserver is held forwarded while the window runs; without it, only while this
  /// is open.
  final HomeserverForwards? _forwards;

  final FleetBackend _backend;
  final Settings _settings;
  String? _person;

  /// The machine the conversation's homeserver is on, when it is the account's own.
  final Machine machine;

  /// The project whose conversation this is.
  final Project project;

  /// Who has joined, or null before the machine answered.
  List<MessageMember>? members;

  /// This computer's remembered person, only while present in the daemon's member answer.
  MessageMember? get joinedAs => members?.where((each) => each.person == _person).firstOrNull;

  /// Whether [joinedAs] was invited with an account the person had, as remembered beyond this dialog: it keeps its
  /// own password, so no new one is offered.
  bool get invited => joinedAs != null && _settings.messageInvited(machine.name, project.name);

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

  /// The latest confirmed removal answer, including the daemon's explanation.
  MessageMemberRemoved? removed;

  /// Whether this daemon has served removal, or has not refused the method yet.
  bool removalSupported = true;

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
  Future<void> load() => _asking(_loadMembers);

  Future<void> _loadMembers({String? joinedPerson}) async {
    final answer = await _backend.messageMembers(project.name);
    if (_gone) return;
    members = List<MessageMember>.unmodifiable(answer);
    final person = joinedPerson ?? _person;
    _person = answer.any((each) => each.person == person) ? person : null;
    if (_person == null) {
      _joined = null;
      _pendingJoin = null;
      _pendingPerson = null;
    }
    await _settings.rememberMessagePerson(machine.name, project.name, _person);
  }

  /// Removes [person], then asks the daemon for the authoritative member list.
  Future<void> remove(String person) async {
    if (busy || !removalSupported) return;
    removed = null;
    await _asking(() async {
      try {
        final answer = await _backend.removeMessageMember(project.name, person);
        if (_gone) return;
        removed = answer;
        alreadyJoined = null;
        await _loadMembers();
      } on FeatureNotSupported catch (unsupported) {
        if (unsupported.method != 'RemoveMessageMember') rethrow;
        removalSupported = false;
        problem = 'this Porelo cannot remove an account from the room yet';
      }
    });
  }

  /// Replaces the confirmed account's password after an explicit request.
  Future<void> newPassword() async {
    final member = joinedAs;
    if (member == null || busy || invited) return;
    await join(member.person, reset: true);
  }

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
    await _loadMembers(joinedPerson: person);
    if (_gone || joinedAs == null) return;
    // Remembered before the forward, which can fail: the dialog opened again, or without the forward, still knows.
    await _settings.rememberMessageInvited(machine.name, project.name, invited: answer.invited);
    if (_gone) return;
    await _forwardTheHomeserver(answer);
    if (_gone) return;
    if (forwardProblem != null) {
      problem = forwardProblem;
      return;
    }
    _joined = answer;
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
        case 'NoSuchMember':
          problem = '${said['person'] ?? 'This person'} has not joined ${project.name}’s conversation.';
        case 'ConversationRefused':
          problem = 'The transport refused it: ${said['message'] ?? ''}';
        case 'NoSuchProject':
          problem = '${project.name} is not on this machine.';
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
    _admissionChanges?.removeListener(_notify);
    _joined = null;
    _pendingJoin = null;
    _pendingPerson = null;
    final held = _forward;
    _forward = null;
    unawaited(held?.close());
    super.dispose();
  }
}

/// Whom a project's room takes, as the window knows it.
sealed class RoomAdmission {
  const RoomAdmission();
}

/// Any name: the project is the machine's own, not one of the organization's.
class AnyName extends RoomAdmission {
  /// The one answer.
  const AnyName();
}

/// Only these logins: those holding a current card in the organization's project.
class AdmittedLogins extends RoomAdmission {
  /// Constructor taking the logins, the asking person's own first where they are one.
  const AdmittedLogins(this.logins, {this.yours});

  /// The logins the room admits; empty where it admits nobody yet.
  final List<String> logins;

  /// The asking person's own login, where it is one of [logins].
  final String? yours;
}

/// The organization is not read, so whom the room admits cannot be said: not yet, or with [problem] where its read
/// failed.
class AdmissionUnread extends RoomAdmission {
  /// Constructor taking why the read failed, or nothing while it is still to come.
  const AdmissionUnread({this.problem});

  /// Why the organization could not be read, in its own words; null while it is not read yet.
  final String? problem;
}

/// Whom [project]'s room on [machine] admits: where [machine] is a host the organization has carry its project of
/// that name, the logins of its admins and members whose card holds its roles and has not run out by [today]; any
/// name for a project of the machine's own, a same-named one included, or where there is no organization.
/// [organizationRead] false says the organization is there but not read, [problem] why where its read failed.
///
/// The machine admits only the logins with a key current today that the last start placed there. The window reads
/// neither those keys nor whether a member is locked, as the organization's view names no lock: a login offered here
/// can still be refused by the machine, which then says so.
RoomAdmission roomAdmission(
  String project, {
  required Machine machine,
  required bool organizationRead,
  OrganizationView? view,
  String? problem,
  DateTime? today,
}) {
  if (!organizationRead) return AdmissionUnread(problem: problem);
  final listed = view?.projects.where((each) => each.name == project).firstOrNull;
  final card = machine.hostCard;
  if (view == null || listed == null || card == null) return const AnyName();
  final host = view.hosts.where((each) => each.name == card.name).firstOrNull;
  final carried =
      listed.host == card.name ||
      (host != null && (host.projects.contains(project) || host.repositories.containsKey(project)));
  if (!carried) return const AnyName();
  final now = (today ?? DateTime.now()).toUtc();
  final day = DateTime.utc(now.year, now.month, now.day);
  bool current(OrganizationPerson person) {
    final until = DateTime.tryParse(person.expires ?? '');
    return until == null || !DateTime.utc(until.year, until.month, until.day).isBefore(day);
  }

  bool holds(String login) => view.persons.any(
    (person) =>
        person.login == login &&
        (person.standing == CardStanding.trusted || person.standing == CardStanding.notYet) &&
        current(person),
  );
  final logins = <String>{
    for (final login in <String>[...listed.admins, ...listed.members])
      if (holds(login)) login,
  }.toList();
  final yours = logins.remove(view.me);
  if (yours) logins.insert(0, view.me);
  return AdmittedLogins(List<String>.unmodifiable(logins), yours: yours ? view.me : null);
}
