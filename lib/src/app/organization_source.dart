import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'host_progress.dart';

/// How a person's card stands in the organization.
enum CardStanding {
  /// The identity source vouches for its key and it is not revoked.
  trusted,

  /// It was accepted before the identity source could say whether its key is theirs: it holds its roles all the same.
  notYet,

  /// It was revoked, and holds in every project at once.
  revoked,

  /// The store refused it: it is answered, but is no card, and holds nothing.
  refused,
}

/// One person of the organization, by their card.
@immutable
class OrganizationPerson {
  /// Keeps the card's public parts and how it stands.
  const OrganizationPerson({required this.login, required this.standing, this.key, this.words, this.expires});

  /// Their login at the identity source.
  final String login;

  /// How their card stands.
  final CardStanding standing;

  /// Their key's fingerprint, absent where the card could not be read.
  final String? key;

  /// The store's own words on why the card stands as it does, where it gave any.
  final String? words;

  /// The day the card runs out, where the store said.
  final String? expires;
}

/// One project of the organization.
@immutable
class OrganizationProject {
  /// Keeps its card and who belongs to it.
  const OrganizationProject({
    required this.name,
    required this.admins,
    this.members = const [],
    this.host,
    this.repositories,
  });

  /// Its name.
  final String name;

  /// The logins of its project admins.
  final List<String> admins;

  /// The logins of its other members.
  final List<String> members;

  /// The host carrying it: a project is on one host at a time. Absent until a host admin puts it on one.
  final String? host;

  /// How many repositories it has, where the store said: they stand in the project's own repository.
  final int? repositories;
}

/// One row of a host's admins as the store answered it: one per key, backup keys among them.
@immutable
class HostAdminKey {
  /// Keeps the row.
  const HostAdminKey({required this.login, required this.key, this.backup = false});

  /// Whose key it is.
  final String login;

  /// The public key, absent where the answer gave none.
  final String? key;

  /// Whether it is a backup key, which is no admin of its own.
  final bool backup;
}

/// One host of the organization.
@immutable
class OrganizationHost {
  /// Keeps its card and who administers it.
  const OrganizationHost({
    required this.name,
    this.address,
    this.port,
    this.hostKey,
    this.webPort,
    this.gitPort,
    this.matrixPort,
    this.admins = const [],
    this.adminKeys = const [],
    this.projects = const [],
  });

  /// Its name.
  final String name;

  /// Its address, absent until its host admin entered it.
  final String? address;

  /// Its ssh port, absent until its host admin entered it.
  final int? port;

  /// Its host key, absent until its host admin entered it.
  final String? hostKey;

  /// The local forge's web port on it, from its card.
  final int? webPort;

  /// The local forge's git port on it, from its card.
  final int? gitPort;

  /// The homeserver's port on it, from its card.
  final int? matrixPort;

  /// The logins of its host admins; a backup key is no admin of its own.
  final List<String> admins;

  /// Every key of its host admins, backup keys among them: the pin a first `up` starts from.
  final List<HostAdminKey> adminKeys;

  /// The projects it carries.
  final List<String> projects;
}

/// One state of the organization, as the store answered it for the person asking.
@immutable
class OrganizationView {
  /// Keeps everything one read answered, at one revision.
  const OrganizationView({
    this.stale = false,
    this.notes = const [],
    required this.name,
    required this.keptIn,
    this.settings,
    this.forge,
    required this.vouchedBy,
    required this.revision,
    required this.me,
    this.persons = const [],
    this.projects = const [],
    this.hosts = const [],
    this.owners = const [],
  });

  /// The organization's name.
  final String name;

  /// Where it is kept, in the store's words.
  final String keptIn;

  /// This machine's organization settings as Porelo answers them, handed to a new host unread; absent where not said.
  final String? settings;

  /// The host of the organization's address, as `known_hosts` names it; absent where not said.
  final String? forge;

  /// What vouches for its people's keys, in the store's words.
  final String vouchedBy;

  /// The revision every part of this view rests on.
  final String revision;

  /// The login of the person asking.
  final String me;

  /// Its people.
  final List<OrganizationPerson> persons;

  /// Its projects.
  final List<OrganizationProject> projects;

  /// Its hosts.
  final List<OrganizationHost> hosts;

  /// The logins of its organization owners; a backup key is no owner of its own.
  final List<String> owners;

  /// Whether this is the last state read because the store could not be reached.
  final bool stale;

  /// What the store warns of: changes it refused, a sole holder with no backup key.
  final List<String> notes;

  /// The asking person's own card, or null where they have none.
  OrganizationPerson? get myCard => persons.where((person) => person.login == me).firstOrNull;

  /// Whether the person holds any role: a revoked card or none holds nothing, so the page offers them no action.
  bool get holdsRoles => myCard?.standing == CardStanding.trusted || myCard?.standing == CardStanding.notYet;

  /// Whether the person may change the organization's structure.
  bool get isOwner => holdsRoles && owners.contains(me);

  /// The hosts this person has to do with: those they administer, and those carrying a project of theirs.
  List<OrganizationHost> get myHosts => !holdsRoles
      ? const []
      : [
          for (final host in hosts)
            if (host.admins.contains(me) ||
                projects.any(
                  (project) =>
                      project.host == host.name && (project.admins.contains(me) || project.members.contains(me)),
                ))
              host,
        ];

  /// The projects on no host yet, which a host admin can put on theirs: a project is on one host at a time.
  List<OrganizationProject> get projectsOnNoHost => [
    for (final project in projects)
      if (project.host == null) project,
  ];

  /// The persons one can name as a project admin or a first host admin.
  List<OrganizationPerson> get holdingRoles => [
    for (final person in persons)
      if (person.standing == CardStanding.trusted || person.standing == CardStanding.notYet) person,
  ];
}

/// One project as `project list` answers it for the person asking.
@immutable
class ListedProject {
  /// Keeps where it comes from and how the person stands in it.
  const ListedProject({
    required this.name,
    required this.source,
    this.role,
    this.locked = false,
    this.host,
    this.stale = false,
  });

  /// Its name.
  final String name;

  /// `organization`, `local` or `built-in`.
  final String source;

  /// The person's role in it, where it has roles.
  final String? role;

  /// Whether the person is locked in it: listed, but may do nothing.
  final bool locked;

  /// The host carrying it, where one does.
  final String? host;

  /// Whether the answer it came in is the last state read, because the store could not be reached.
  final bool stale;

  /// Whether it is the organization's.
  bool get ofTheOrganization => source == 'organization';
}

/// What was last answered of a project's address: absence is a state of its own, and never a forge matched.
@immutable
class KnownAddress {
  /// Keeps the address, or why there is none to show.
  const KnownAddress({this.address, this.problem});

  /// The address of its project repository, absent where none is filed or none could be read.
  final String? address;

  /// Why it could not be read, in Porelo's words, where it could not.
  final String? problem;
}

/// One repository of a project: a place of work, named by the address it is worked on at.
@immutable
class ProjectRepository {
  /// Keeps its name and address.
  const ProjectRepository({required this.name, required this.address});

  /// Its name.
  final String name;

  /// Where it is worked on.
  final String address;
}

/// One member of a project, by their card.
@immutable
class ProjectMember {
  /// Keeps who they are, what they do and how their card stands.
  const ProjectMember({required this.login, required this.role, required this.standing, this.locked = false});

  /// Their login.
  final String login;

  /// Their role in the project.
  final String role;

  /// How their card stands.
  final CardStanding standing;

  /// Whether they are locked: listed, but may do nothing until a project admin unlocks them.
  final bool locked;
}

/// One project as the store answered it.
@immutable
class ProjectView {
  /// Keeps everything one read answered, at one revision.
  const ProjectView({
    required this.name,
    required this.revision,
    this.repositoriesRevision,
    this.repositoriesProblem,
    this.host,
    this.address,
    this.opened = true,
    this.repositories = const [],
    this.members = const [],
    this.roles = const [],
  });

  /// The project repository's revision, the base of a change to its repositories; absent where they were not read.
  final String? repositoriesRevision;

  /// Why its repositories could not be read, where they could not.
  final String? repositoriesProblem;

  /// Its name.
  final String name;

  /// The revision every part of this view rests on.
  final String revision;

  /// The host carrying it: a project is on one host at a time. Absent until a host admin puts it on one.
  final String? host;

  /// The address of its project repository, filed by its project admins; absent until one named it.
  final String? address;

  /// Whether its project admin has opened it: until then it has no repositories, and only their key can sign the first
  /// `project.yml`.
  final bool opened;

  /// Its repositories.
  final List<ProjectRepository> repositories;

  /// Its members.
  final List<ProjectMember> members;

  /// The roles a member can be given, the one a new member gets first.
  final List<String> roles;

  /// The role that may change the project.
  static const adminRole = 'admin';

  /// The logins of its project admins.
  List<String> get admins => [
    for (final member in members)
      if (member.role == adminRole) member.login,
  ];
}

/// What can be changed on the organization's and a project's pages.
enum OrganizationChange {
  /// File the person's own card.
  addCard,

  /// Change the person's own key.
  changeCard,

  /// Revoke a card: one's own, or any for an organization owner.
  revokeCard,

  /// Change a host's address and host key.
  changeHost,

  /// Name another host admin.
  addHostAdmin,

  /// Remove a host admin.
  removeHostAdmin,

  /// Put a project on a host, with every member it has.
  addProjectToHost,

  /// Take a project off a host.
  removeProjectFromHost,

  /// Add a project and name its project admin.
  addProject,

  /// Name another project admin.
  changeProjectAdmin,

  /// Remove a project.
  removeProject,

  /// Add a host and name its first host admin.
  addHost,

  /// Remove a host.
  removeHost,

  /// Name another organization owner.
  addOrganizationOwner,

  /// Remove an organization owner.
  removeOrganizationOwner,

  /// Its project admin's first opening of a project, which only their key can do.
  openProject,

  /// Change the address of a project's repository.
  changeProjectRepository,

  /// Add a repository to a project.
  addProjectRepository,

  /// Remove a repository from a project.
  removeProjectRepository,

  /// Add a member to a project, with their role.
  addProjectMember,

  /// Change a member's role.
  changeProjectMemberRole,

  /// Remove a member from a project.
  removeProjectMember,

  /// Lock a member: listed, but may do nothing.
  lockProjectMember,

  /// Unlock a member.
  unlockProjectMember,

  /// Fill an empty repository the person made as a new organization, with them as its only owner.
  createOrganization,

  /// Name the organization this computer reads.
  chooseOrganization;

  /// Whether it can be asked for with no organization read, and so is made against no revision.
  bool get standsBeforeAnOrganization => this == createOrganization || this == chooseOrganization;
}

/// One change as the store is asked for it: who asks, against which revision, and an id, so that the same id asked again
/// gets the same answer and a store that moved on refuses it.
@immutable
class OrganizationWrite {
  /// Keeps plain data only: no path, commit or signature.
  const OrganizationWrite({
    required this.change,
    required this.input,
    required this.person,
    required this.base,
    required this.id,
  });

  /// What is changed.
  final OrganizationChange change;

  /// Its values, by name.
  final Map<String, String> input;

  /// The login of the acting person.
  final String person;

  /// The revision it was made against.
  final String base;

  /// Its id.
  final String id;
}

/// A key this person could file, and what the identity source says of it.
@immutable
class OrganizationKey {
  /// Keeps its fingerprint and the source's answer; [vouched] is null where the source could not say.
  const OrganizationKey({required this.fingerprint, required this.vouched, this.label = ''});

  /// Its fingerprint.
  final String fingerprint;

  /// Where it is, in the person's words.
  final String label;

  /// Whether the identity source lists it for this person; null where it could not say.
  final bool? vouched;
}

/// A refusal in the store's own words, or no answer at all.
class OrganizationRefused implements Exception {
  /// Keeps the words; [answered] is false where no answer came, so the same id is asked again.
  const OrganizationRefused(this.words, {this.answered = true, this.reason});

  /// The sentence shown.
  final String words;

  /// Whether the store answered.
  final bool answered;

  /// Its reason for a program, where it gave one.
  final String? reason;

  @override
  String toString() => words;
}

/// Where the organization is read and changed, whatever keeps it.
abstract interface class OrganizationSource {
  /// The organization's current state for this person.
  Future<OrganizationView> read();

  /// One project's current state.
  Future<ProjectView> readProject(String project);

  /// The keys this person could file, each with the identity source's answer.
  Future<List<OrganizationKey>> myKeys();

  /// The organization's projects this person is in, then those registered on this computer alone.
  Future<List<ListedProject>> myProjects();

  /// Asks for [write]; a store that refuses throws [OrganizationRefused] in its words.
  Future<void> apply(OrganizationWrite write);
}

/// This person's one connection to each host: ssh, its pinned host key and the tunnels, whatever number of projects it
/// carries. Each throws [OrganizationRefused] in words a person can act on.
abstract class HostConnections extends ChangeNotifier {
  /// Whether this computer is connected to [host].
  bool connected(String host);

  /// Sets up the connection to [host] and raises it.
  Future<void> connect(String host);

  /// Takes the connection to [host] down.
  Future<void> disconnect(String host);

  /// Asks [host] to fetch its organization's and its projects' state now, rather than within five minutes, and what it
  /// says then. Only a host admin has this way in.
  Future<HostProgress> refresh(String host);

  /// What [host] says of how far it has come. Only a host admin has this way in.
  Future<HostProgress> progress(String host);
}

/// One answer a frame uses without waiting for it, and when it came.
class _Kept<T> {
  T? value;
  String? problem;
  DateTime? at;
  Future<void>? reading;
}

/// The organization as the page shows it: only what the store answered, and the last list when it no longer answers.
class Organization extends ChangeNotifier {
  /// Reads and changes it through [source].
  Organization(this.source, {DateTime Function()? clock, Random? random})
    : _clock = clock ?? DateTime.now,
      _random = random ?? Random.secure();

  /// Where it is kept.
  final OrganizationSource source;

  final DateTime Function() _clock;
  final Random _random;
  final _unanswered = <String, ({String id, String base})>{};
  int _reads = 0;
  final _addresses = <String, _Kept<KnownAddress>>{};
  final _listed = _Kept<List<ListedProject>>();
  Future<void> _answersInTurn = Future<void>.value();

  /// How long [addressOf] and [whyNoRemoval] go on using an answer before the next need reads it again.
  static const answersKeptFor = Duration(minutes: 5);

  /// The last state read, or null before any.
  OrganizationView? view;

  /// When [view] was read.
  DateTime? readAt;

  /// Why the last read gave nothing, or null where it did.
  String? problem;

  /// Whether the last read said this computer names no organization yet.
  bool noOrganization = false;

  /// Whether a change is being asked for.
  bool busy = false;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  /// What is known of [project]'s address, or null where nothing is yet; with [ask], reads it where it is not known.
  ///
  /// A frame calls this, so it never waits and never reads twice at once; reads go one after the other, as each fetches.
  KnownAddress? addressOf(String project, {bool ask = true}) {
    final kept = _addresses[project] ??= _Kept();
    if (ask) unawaited(_readAddress(project, kept));
    return kept.value;
  }

  /// [project]'s address as it is read now, or as kept where that answer is still good.
  Future<KnownAddress> readAddress(String project) async {
    final kept = _addresses[project] ??= _Kept();
    await _readAddress(project, kept);
    return kept.value!;
  }

  Future<void> _readAddress(String project, _Kept<KnownAddress> kept) => _keeping(kept, () async {
    try {
      kept.value = KnownAddress(address: (await source.readProject(project)).address);
    } on OrganizationRefused catch (refused) {
      kept.value = KnownAddress(problem: refused.words);
    } on Exception {
      kept.value = const KnownAddress(problem: 'Its address could not be read.');
    }
  });

  /// Why [project] cannot be removed here, or null where `project list` says it is registered here alone.
  ///
  /// Removing a project loses data, so everything but that one answer is a reason not to offer it, an answer not yet
  /// read and one the store could not vouch for among them. A frame calls this, so it never waits.
  String? whyNoRemoval(String project) {
    unawaited(
      _keeping(_listed, () async {
        try {
          _listed.value = await source.myProjects();
          _listed.problem = null;
        } on OrganizationRefused catch (refused) {
          _listed.problem = refused.words;
        } on Exception {
          _listed.problem = 'Its source could not be read.';
        }
      }),
    );
    if (_listed.problem case final problem?) return 'Porelo cannot say whose this project is: $problem';
    final listed = _listed.value;
    if (listed == null) return 'Porelo has not said yet whose this project is.';
    if (listed.any((each) => each.stale)) {
      return 'Porelo cannot reach the organization just now, so it cannot say whose this project is.';
    }
    final mine = listed.where((each) => each.name == project).firstOrNull;
    return switch (mine?.source) {
      'local' => null,
      'organization' => 'This project is the organization’s: it is removed from the organization’s page.',
      'built-in' => 'This project comes with Porelo and is always there.',
      null => 'Porelo here lists no project called $project, so it cannot say whose it is.',
      final other => 'Porelo calls this project’s source “$other”, and only a local project is removed here.',
    };
  }

  /// Has the next need read [addressOf] and [whyNoRemoval] again, as every read fetches: this is what *Refresh* does.
  void readAnswersAgain() {
    _listed.at = null;
    for (final kept in _addresses.values) {
      kept.at = null;
    }
  }

  /// Runs [read] in turn, unless [kept] is good or being read; ends when the answer for it is there.
  Future<void> _keeping<T>(_Kept<T> kept, Future<void> Function() read) {
    if (kept.reading case final reading?) return reading;
    final at = kept.at;
    if (at != null && _clock().difference(at) < answersKeptFor) return Future<void>.value();
    return kept.reading = _answersInTurn = _answersInTurn.then((_) async {
      await read();
      kept
        ..at = _clock()
        ..reading = null;
      _changed();
    });
  }

  /// Reads it again. A read that answers after a later one was asked for says nothing: it may be the older.
  Future<void> refresh() async {
    readAnswersAgain();
    final read = ++_reads;
    try {
      final answer = await source.read();
      if (read != _reads) return;
      view = answer;
      readAt = _clock();
      problem = null;
      noOrganization = false;
    } on OrganizationRefused catch (refused) {
      if (read != _reads) return;
      problem = refused.words;
      noOrganization = refused.reason == 'no-organization';
    } on Exception {
      if (read != _reads) return;
      problem = 'The organization could not be read.';
      noOrganization = false;
    }
    _changed();
  }

  /// Asks for [change], then reads again; answers the store's words where it refused, and null where it took it.
  ///
  /// Nothing changes on the page before the store's answer and the read after it. The id stays for a change that got no
  /// answer, so that asking again cannot do it twice.
  ///
  /// [base] is the revision it is made against where it is not the organization's as last read.
  Future<String?> write(OrganizationChange change, Map<String, String> input, {String? base}) async {
    final current = view;
    final beforeAny = change.standsBeforeAnOrganization || (noOrganization && change == OrganizationChange.addCard);
    if (current == null && !beforeAny) return 'The organization has not been read yet.';
    if (busy) return 'Another change is still being asked for.';
    final sameChange = '${change.name} ${[for (final entry in input.entries) '${entry.key}=${entry.value}'].join(' ')}';
    // Asked again as it was asked: with no answer it may have been taken, at the revision it was decided on.
    final asked = _unanswered[sameChange] ??= (
      id: _newId(),
      base: change.standsBeforeAnOrganization ? '' : base ?? current?.revision ?? '',
    );
    busy = true;
    _changed();
    String? refusal;
    try {
      await source.apply(
        OrganizationWrite(change: change, input: input, person: current?.me ?? '', base: asked.base, id: asked.id),
      );
      _unanswered.remove(sameChange);
    } on OrganizationRefused catch (refused) {
      if (refused.answered) _unanswered.remove(sameChange);
      refusal = refused.words;
    } on Exception {
      refusal = 'The change could not be asked for. Nothing is known to have changed; look at the list and try again.';
    }
    try {
      // Read in both cases: a store that moved on refused this change, and its new state is what is decided on next.
      await refresh();
    } finally {
      busy = false;
      _changed();
    }
    return refusal;
  }

  String _newId() => [for (var i = 0; i < 16; i++) _random.nextInt(256).toRadixString(16).padLeft(2, '0')].join();
}
