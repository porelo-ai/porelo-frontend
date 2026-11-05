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
    this.opened,
  });

  /// Its name.
  final String name;

  /// Whether its Git repository is filed, or null where an older Porelo does not say.
  final bool? opened;

  /// Whether it is known to have no Git repository yet: an older Porelo saying nothing is not that.
  bool get hasNoRepository => opened == false;

  /// The logins of its project admins.
  final List<String> admins;

  /// The logins of its other members.
  final List<String> members;

  /// The host carrying it: a project is on one host at a time. Absent until a host admin puts it on one.
  final String? host;

  /// How many repositories it has, where the store said: they stand in the project's own repository.
  final int? repositories;
}

/// Everyone in [project], its admins with its members, in the one count every page says.
String peopleOf(OrganizationProject project) {
  final count = {...project.admins, ...project.members}.length;
  return '$count ${count == 1 ? 'person' : 'people'}';
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

  /// Whether neither its address nor its SSH host key is there yet, so it is prepared and not changed.
  bool get hasNoReach => address == null && hostKey == null;

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
    this.address,
    required this.vouchedBy,
    required this.revision,
    required this.me,
    this.persons = const [],
    this.projects = const [],
    this.hosts = const [],
    this.owners = const [],
    this.ownersWithBackup = const [],
    this.organizationAdmins,
  });

  /// The organization's name.
  final String name;

  /// Where it is kept, in the store's words.
  final String keptIn;

  /// This machine's organization settings as Porelo answers them, handed to a new host unread; absent where not said.
  final String? settings;

  /// The host of the organization's address, as `known_hosts` names it; absent where not said.
  final String? forge;

  /// The organization's own address, as `porelo org` answers it; absent where not said.
  final String? address;

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

  /// The owners among [owners] who have made a backup key.
  final List<String> ownersWithBackup;

  /// The logins it lists as Organization Admins, or null while its file is absent: then its owners do that work.
  final List<String>? organizationAdmins;

  /// Whether this is the last state read because the store could not be reached.
  final bool stale;

  /// What the store warns of: changes it refused, a sole holder with no backup key.
  final List<String> notes;

  /// The asking person's own card, or null where they have none.
  OrganizationPerson? get myCard => persons.where((person) => person.login == me).firstOrNull;

  /// Whether the person holds any role: a revoked card or none holds nothing, so the page offers them no action.
  bool get holdsRoles => myCard?.standing == CardStanding.trusted || myCard?.standing == CardStanding.notYet;

  /// Whether the person names the owners and the Organization Admins.
  bool get isOwner => holdsRoles && owners.contains(me);

  /// Whether the person may change the organization's cards, projects and machines and name their admins.
  ///
  /// The one place the rule stands: once the list exists only the list counts, and an unlisted owner is no admin.
  bool get isOrganizationAdmin => holdsRoles && (organizationAdmins ?? owners).contains(me);

  /// Whether the person may name further admins of [host]: its own admins, until the list exists.
  bool mayNameAdminsOf(OrganizationHost host) =>
      organizationAdmins == null ? holdsRoles && host.admins.contains(me) : isOrganizationAdmin;

  /// Where a task on its machine reads [repository] of [project]: that machine's own forge, by the port its card
  /// names. Null for a project on no machine, or on one whose card names no port.
  String? localAddress(String project, String repository) {
    final port = hosts.where((host) => host.projects.contains(project) && host.gitPort != null).firstOrNull?.gitPort;
    return port == null ? null : 'http://127.0.0.1:$port/$project/${endOfAddress(repository)}.git';
  }

  /// What an address ends in, its repository's name there. The machine's forge names a repository so, and Core refuses
  /// a local address that ends otherwise than the central one.
  static String endOfAddress(String address) {
    final bare = address.replaceFirst(RegExp(r'/+$'), '').replaceFirst(RegExp(r'\.git$'), '');
    return bare.substring(bare.lastIndexOf(RegExp('[/:]')) + 1);
  }

  /// Whether the person may remove [host] from the organization: its owners, until the list exists.
  bool mayRemove(OrganizationHost host) =>
      isOrganizationAdmin || (organizationAdmins != null && holdsRoles && host.admins.contains(me));

  /// Whether a project's admin, as [isProjectAdmin] says, may change a member of [role], or give someone that role.
  bool mayChangeMember(String role, {required bool isProjectAdmin}) =>
      organizationAdmins == null || role != ProjectView.adminRole ? isProjectAdmin : isOrganizationAdmin;

  /// Whether [project] is known to have no Git repository: a stale read cannot tell that one is missing.
  bool saysNoRepository(OrganizationProject project) => !stale && project.hasNoRepository;

  /// Whether [project] stands under *My projects*: this person holds a role in it, and it has its Git
  /// repository, as one with none yet stands on the Organization page, where it is made.
  bool isMine(OrganizationProject project) =>
      holdsRoles && !saysNoRepository(project) && (project.admins.contains(me) || project.members.contains(me));

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
  /// Keeps its name, addresses and review policy.
  const ProjectRepository({required this.name, this.address, this.central, this.review});

  /// Its name.
  final String name;

  /// Where it is worked on, absent where no upstream is named.
  final String? address;

  /// Where a machine takes it from: empty where the row names none, so a machine takes nothing from
  /// it, and null where an older Porelo does not say.
  final String? central;

  /// Whether the row is known to name nowhere a machine takes it from.
  bool get namesNoCentral => central != null && central!.isEmpty;

  /// The review policy Core names for it, or null where it names none; unknown words remain visible.
  final String? review;
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
    this.review,
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

  /// The review policy Core names, or null where it names none; unknown words remain visible.
  final String? review;

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

/// One proposed setting and the evidence Core gives for it.
@immutable
class ProjectInitValue {
  /// Keeps the value as display text and its provenance without interpreting the setting.
  const ProjectInitValue({
    required this.key,
    required this.value,
    required this.unknown,
    this.file,
    this.line,
    this.origin,
    this.note,
    this.plugin,
  });

  /// The setting's key.
  final String key;

  /// Its value, with structured JSON preserved as text.
  final String value;

  /// Whether Core cannot determine this value.
  final bool unknown;

  /// Its source file, where named.
  final String? file;

  /// Its source line, where named.
  final int? line;

  /// Its other origin, where named.
  final String? origin;

  /// Core's note about this value.
  final String? note;

  /// The plugin that proposed it, where named.
  final String? plugin;
}

/// A read-only checkout draft, with every warning kept before signing is offered.
@immutable
class ProjectInitDraft {
  /// Keeps only Core's answer; no project file is written by the interface.
  const ProjectInitDraft({
    required this.repository,
    required this.upstream,
    required this.draft,
    required this.revision,
    required this.values,
    required this.disagreements,
    required this.unplaced,
    required this.notPlaced,
    required this.credentialsNeeded,
    required this.plugins,
  });

  /// The repository Core found.
  final String repository;

  /// Its upstream, absent where Core names none.
  final String? upstream;

  /// The proposed project file, shown without editing.
  final String draft;

  /// The revision this draft stands on; absent for a draft with no target project.
  final String? revision;

  /// The proposed settings, with their provenance.
  final List<ProjectInitValue> values;

  /// Conflicting readings, preserving all of Core's alternatives as display text.
  final List<({String key, String values})> disagreements;

  /// Core's unplaced findings, preserved as display text.
  final String unplaced;

  /// Core's explanation of what was not placed, preserved as display text.
  final String notPlaced;

  /// The credential requirements, never credential values.
  final String credentialsNeeded;

  /// Every plugin's state and explanation, including unknown states.
  final List<({String name, String state, String? why})> plugins;
}

/// What can be changed on the organization's and a project's pages.
enum OrganizationChange {
  /// File the person's own card.
  addCard,

  /// Change the person's own key.
  changeCard,

  /// Revoke a card: one's own, or any for an organization owner.
  revokeCard,

  /// Put a person's new card in place of a lost key's: an organization owner's.
  replaceCard,

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

  /// List someone as an Organization Admin; the first listing makes the list that counts from then on.
  addOrganizationAdmin,

  /// Take someone off the list of Organization Admins.
  removeOrganizationAdmin,

  /// Creates a project's Git repository, and signs its first `project.yml`.
  createProjectRepository,

  /// Change whether the project or one of its repositories requires review.
  changeProjectReview,

  /// Sign the draft read from a checkout into a project.
  initializeProject,

  /// Change the address of a project's repository.
  changeProjectRepository,

  /// Add a repository to a project.
  addProjectRepository,

  /// Remove a repository from a project.
  removeProjectRepository,

  /// Names where a machine takes a repository from, on a row that names nowhere.
  nameRepositoryCentral,

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

  /// Reads a checkout's draft without writing, against [project] where one is named.
  Future<ProjectInitDraft> readProjectInit(String checkout, {String? project, String? name, String? upstream});

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

  /// Whether that connection is up: a host still waiting for its first token has made no account to connect to.
  bool up(String host) => connected(host);

  /// Whether the last *Connect* found [host] waiting for its first token, so its connection cannot be up.
  bool waitsForToken(String host) => false;

  /// Sets up the connection to [host] and raises it.
  Future<void> connect(String host);

  /// Takes the connection to [host] down.
  Future<void> disconnect(String host);

  /// Asks [host] to fetch its organization's and its projects' state now, rather than within five minutes, and what it
  /// says then. Only a host admin has this way in.
  Future<HostProgress> refresh(String host);

  /// What [host] says of how far it has come. Only a host admin has this way in.
  Future<HostProgress> progress(String host);

  /// How [project] on [host] stands with the central forge; cannot say where this computer cannot ask.
  Future<CentralState> central(String host, String project) async => const CentralState();
}

/// One answer a frame uses without waiting for it, and when it came.
class _Kept<T> {
  T? value;
  String? problem;
  DateTime? at;
  Future<void>? reading;
}

/// A list change kept while it runs, or until its refusal is retried or dropped.
class OrganizationRowChange {
  /// Keeps the request independently of the dialog and page that started it.
  OrganizationRowChange(this.change, Map<String, String> input, this.base)
    : input = Map<String, String>.unmodifiable(input);

  /// The operation to retry.
  final OrganizationChange change;

  /// The original values to retry.
  final Map<String, String> input;

  /// The revision the person saw.
  final String? base;

  /// Whether its answer and the reads after it are still awaited.
  bool running = true;

  /// A refusal that stays until the person acts on it.
  String? refusal;

  /// Whether retry must replay the original id because the store never answered.
  bool unanswered = false;

  /// The row to mark in [scope], including the project row from which a nested change was asked.
  ({String scope, String name, String doing})? inList(String scope) {
    final primary = target(change, input);
    if (primary?.scope == scope) return primary;
    if (primary != null && scope == 'organization-projects' && input.containsKey('project')) {
      return (scope: scope, name: input['project']!, doing: primary.doing);
    }
    return null;
  }

  /// The list and row it marks, absent for changes that stay in a dialog.
  static ({String scope, String name, String doing})? target(OrganizationChange change, Map<String, String> input) {
    final project = input['project'] ?? '';
    final host = input['host'] ?? '';
    final login = input['login'] ?? '';
    return switch (change) {
      OrganizationChange.createProjectRepository => (
        scope: 'project-create $project',
        name: project,
        doing: 'Creating…',
      ),
      OrganizationChange.addProject => (scope: 'organization-projects', name: project, doing: 'Adding…'),
      OrganizationChange.removeProject => (scope: 'organization-projects', name: project, doing: 'Removing…'),
      OrganizationChange.addHost => (scope: 'organization-hosts', name: host, doing: 'Adding…'),
      OrganizationChange.removeHost => (scope: 'organization-hosts', name: host, doing: 'Removing…'),
      OrganizationChange.addOrganizationOwner => (scope: 'organization-owners', name: login, doing: 'Adding…'),
      OrganizationChange.removeOrganizationOwner => (scope: 'organization-owners', name: login, doing: 'Removing…'),
      OrganizationChange.addOrganizationAdmin => (scope: 'organization-admins', name: login, doing: 'Adding…'),
      OrganizationChange.removeOrganizationAdmin => (scope: 'organization-admins', name: login, doing: 'Removing…'),
      OrganizationChange.addHostAdmin => (scope: 'host-admins $host', name: login, doing: 'Adding…'),
      OrganizationChange.removeHostAdmin => (scope: 'host-admins $host', name: login, doing: 'Removing…'),
      OrganizationChange.addProjectToHost => (scope: 'organization-projects', name: project, doing: 'Adding…'),
      OrganizationChange.removeProjectFromHost => (scope: 'organization-projects', name: project, doing: 'Removing…'),
      OrganizationChange.addProjectRepository => (
        scope: 'project-repositories $project',
        name: input['repository'] ?? '',
        doing: 'Adding…',
      ),
      OrganizationChange.removeProjectRepository => (
        scope: 'project-repositories $project',
        name: input['repository'] ?? '',
        doing: 'Removing…',
      ),
      OrganizationChange.nameRepositoryCentral => (
        scope: 'project-repositories $project',
        name: input['repository'] ?? '',
        doing: 'Naming…',
      ),
      OrganizationChange.addProjectMember => (scope: 'project-members $project', name: login, doing: 'Adding…'),
      OrganizationChange.removeProjectMember => (scope: 'project-members $project', name: login, doing: 'Removing…'),
      OrganizationChange.addCard => (scope: 'organization-people', name: login, doing: 'Adding…'),
      _ => null,
    };
  }
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

  /// Told of each change the store took, for what the window keeps of it itself.
  void Function(OrganizationChange change, Map<String, String> input)? afterWrite;

  final _rowChanges = <OrganizationRowChange>[];
  final _writeReads = <Future<void> Function()>[];
  final _projectBases = <String, ({String revision, String? repositories})>{};
  final _signedReviewChoices = <String, String>{};
  Completer<void>? _writeFinished;

  /// Completes when the current change and its rereads finish, including after an early dialog close.
  Future<void> get whenIdle => _writeFinished?.future ?? Future<void>.value();

  /// Provisional rows, including refusals kept after leaving a page.
  Iterable<OrganizationRowChange> get rowChanges => List<OrganizationRowChange>.unmodifiable(_rowChanges);

  /// Keeps only the revisions already read by a project's page, for an answered request's next attempt.
  void rememberProjectRevision(ProjectView project) {
    _projectBases[project.name] = (revision: project.revision, repositories: project.repositoriesRevision);
  }

  /// The default for a new repository: Core's policy, or this window's last confirmed project choice.
  ///
  /// This does not establish the current policy when Core names none; the project page still says it cannot tell.
  String? reviewForNewRepositories(ProjectView project) => project.review ?? _signedReviewChoices[project.name];

  /// What the current change is waiting for.
  String? changeProgress;

  /// Keeps the existing page reread within the change's busy interval.
  void addWriteRead(Future<void> Function() read) => _writeReads.add(read);

  /// Stops asking a page that has closed to reread after changes.
  void removeWriteRead(Future<void> Function() read) => _writeReads.remove(read);

  /// Drops only the provisional row; an unanswered request retains its safe retry id.
  void dropRowChange(OrganizationRowChange change) {
    if (change.running) return;
    _rowChanges.remove(change);
    _changed();
  }

  /// Why a retry must wait, including a project revision that has not been reviewed since a refusal.
  String? whyNoRetry(OrganizationRowChange change) {
    if (busy) return 'Another change is still being asked for.';
    if (!change.unanswered && change.base != null && !_projectBases.containsKey(change.input['project'])) {
      return 'Review the project before asking again.';
    }
    return null;
  }

  /// Retries the original request, reusing its id where no answer came.
  Future<void> retryRowChange(OrganizationRowChange change) async {
    if (change.running || whyNoRetry(change) != null) return;
    final project = _projectBases[change.input['project']];
    final repository =
        change.change == OrganizationChange.addProjectRepository ||
        change.change == OrganizationChange.removeProjectRepository ||
        change.change == OrganizationChange.nameRepositoryCentral;
    final base = change.base == null
        ? null
        : (repository ? project?.repositories : null) ?? project?.revision ?? change.base;
    await write(change.change, change.input, base: base, provisional: true);
  }

  /// How long [addressOf] and [whyNoRemoval] go on using an answer before the next need reads it again.
  static const answersKeptFor = Duration(minutes: 5);

  /// Whether the person closed the page's explanation; kept while the window is open, as the page comes and goes.
  bool explanationClosed = false;

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
      return 'Porelo cannot reach the Porelo organization just now, so it cannot say whose this project is.';
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
      problem = 'The Porelo organization could not be read.';
      noOrganization = false;
    }
    _changed();
  }

  /// Asks for [change], then reads again; answers the store's words where it refused, and null where it took it.
  ///
  /// Provisional rows say only what is being asked; source rows change only after the reads. The id stays for a change
  /// that got no answer, so that asking again cannot do it twice.
  ///
  /// [base] is the revision it is made against where it is not the organization's as last read.
  Future<String?> write(
    OrganizationChange change,
    Map<String, String> input, {
    String? base,
    bool provisional = false,
  }) async {
    final current = view;
    final beforeAny = change.standsBeforeAnOrganization || (noOrganization && change == OrganizationChange.addCard);
    if (current == null && !beforeAny) return 'The Porelo organization has not been read yet.';
    if (busy) return 'Another change is still being asked for.';
    final sameChange = '${change.name} ${[for (final entry in input.entries) '${entry.key}=${entry.value}'].join(' ')}';
    // Asked again as it was asked: with no answer it may have been taken, at the revision it was decided on.
    final asked = _unanswered[sameChange] ??= (
      id: _newId(),
      base: change.standsBeforeAnOrganization ? '' : base ?? current?.revision ?? '',
    );
    OrganizationRowChange? row;
    final target = OrganizationRowChange.target(change, input);
    if (provisional && target != null) {
      _rowChanges.removeWhere((each) {
        final other = OrganizationRowChange.target(each.change, each.input);
        return other?.scope == target.scope && other?.name == target.name;
      });
      row = OrganizationRowChange(change, input, base);
      _rowChanges.add(row);
    }
    busy = true;
    _writeFinished = Completer<void>();
    changeProgress = 'Asking for the change…';
    _changed();
    String? refusal;
    try {
      await source.apply(
        OrganizationWrite(change: change, input: input, person: current?.me ?? '', base: asked.base, id: asked.id),
      );
      _unanswered.remove(sameChange);
      if ((change == OrganizationChange.createProjectRepository ||
              change == OrganizationChange.addProject ||
              change == OrganizationChange.changeProjectReview) &&
          input['repository'] == null &&
          input['project'] != null &&
          input['review'] != null) {
        _signedReviewChoices[input['project']!] = input['review']!;
      }
      afterWrite?.call(change, input);
      if (change == OrganizationChange.chooseOrganization) {
        _rowChanges.clear();
        _projectBases.clear();
        _unanswered.clear();
        _signedReviewChoices.clear();
      }
    } on OrganizationRefused catch (refused) {
      if (refused.answered) _unanswered.remove(sameChange);
      if (row != null) {
        row.unanswered = !refused.answered;
        if (refused.answered && row.base != null) _projectBases.remove(input['project']);
      }
      refusal = refused.reason == 'moved-on'
          ? '${refused.words.endsWith('.') ? refused.words : '${refused.words}.'} The page has read what changed: look at it, and ask again from there.'
          : refused.words;
    } on Exception {
      row?.unanswered = true;
      refusal = 'The change could not be asked for. Nothing is known to have changed; look at the list and try again.';
    }
    try {
      // Read in both cases: a store that moved on refused this change, and its new state is what is decided on next.
      changeProgress = 'Reading the Porelo organization again…';
      _changed();
      await refresh();
      if (_writeReads.isNotEmpty) {
        changeProgress = 'Reading the project again…';
        _changed();
        for (final read in List.of(_writeReads)) {
          await read();
        }
      }
    } finally {
      if (row != null) {
        row.running = false;
        row.refusal = refusal;
        if (refusal == null) _rowChanges.remove(row);
      }
      busy = false;
      changeProgress = null;
      _writeFinished?.complete();
      _writeFinished = null;
      _changed();
    }
    return refusal;
  }

  String _newId() => [for (var i = 0; i < 16; i++) _random.nextInt(256).toRadixString(16).padLeft(2, '0')].join();
}
