import 'package:porelo_frontend/src/app/host_progress.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';

/// An organization for one person, holding what the store would answer, recording each write and able to refuse it.
class FixtureOrganization implements OrganizationSource {
  /// Starts at [view], with [keys] offered to file.
  FixtureOrganization(this.view, {this.keys = const []});

  /// What the next read answers.
  OrganizationView view;

  /// What [myKeys] answers.
  List<OrganizationKey> keys;

  /// Every write asked for, in order.
  final writes = <OrganizationWrite>[];

  /// The refusal the next write gets, once.
  OrganizationRefused? refuseNext;

  /// The refusal every read gets while set.
  OrganizationRefused? refuseReads;

  /// What every write waits for, where a test needs one still being asked for.
  Future<void>? holdWrites;

  /// Whether a project-file change is written by the store itself, as an older Porelo does.
  bool writesProjectFiles = false;

  /// What a taken write changes, where a test needs the page to read something new.
  OrganizationView Function(OrganizationWrite write)? afterWrite;

  /// The hosts Porelo was asked to hand the vault's token to, and what it answers.
  final List<String> handedTo = [];

  /// Whether Porelo says it handed the token over.
  bool handsOver = true;

  @override
  Future<bool> handTokenTo(String host) async {
    if (refuseNext case final refused?) {
      refuseNext = null;
      throw refused;
    }
    handedTo.add(host);
    return handsOver;
  }

  @override
  Future<OrganizationView> read() async {
    if (refuseReads case final refused?) throw refused;
    return view;
  }

  /// What [readProject] answers, by project.
  Map<String, ProjectView> projects = {'demo': demoProject};

  @override
  Future<ProjectView> readProject(String project) async {
    if (refuseReads case final refused?) throw refused;
    return projects[project] ?? (throw OrganizationRefused('There is no project $project.'));
  }

  @override
  Future<ProjectInitDraft> readProjectInit(String checkout, {String? project, String? name, String? upstream}) async =>
      throw const OrganizationRefused('No checkout draft was supplied.');

  @override
  Future<List<OrganizationKey>> myKeys() async => keys;

  /// What [myProjects] answers; the view's own projects of the person where null.
  List<ListedProject>? listed;

  @override
  Future<List<ListedProject>> myProjects() async {
    if (refuseReads case final refused?) throw refused;
    return listed ??
        [
          for (final project in view.projects)
            if (project.admins.contains(view.me) || project.members.contains(view.me))
              ListedProject(
                name: project.name,
                source: 'organization',
                role: project.admins.contains(view.me) ? 'admin' : 'developer',
                host: project.host,
              ),
        ];
  }

  @override
  Future<void> apply(OrganizationWrite write) async {
    writes.add(write);
    await holdWrites;
    if (refuseNext case final refused?) {
      refuseNext = null;
      throw refused;
    }
    // As Porelo does: a project file that exists is the project admin's to change, from the entry it says.
    // Removing has nothing to write, so it comes with words alone.
    if (write.change.byHand && !writesProjectFiles) {
      throw write.change == OrganizationChange.removeProjectRepository
          ? ProjectFileByHand(project: write.input['project'] ?? '', entry: null, words: 'take the entry out')
          : ProjectFileByHand(project: write.input['project'] ?? '', entry: entryFor(write));
    }
    if (afterWrite case final change?) view = change(write);
  }

  /// The entry a project-file change answers.
  static String entryFor(OrganizationWrite write) => 'entry: ${write.change.name}\n';
}

/// Connections that record what is asked, and can refuse the next one.
class FixtureConnections extends HostConnections {
  /// What [lastAttempt] answers.
  final lastAttempts = <String, ConnectAttempt>{};

  @override
  ConnectAttempt? lastAttempt(String host) => lastAttempts[host];

  /// Starts connected to [hosts].
  FixtureConnections([Iterable<String> hosts = const []]) : hosts = {...hosts};

  /// The hosts connected to.
  final Set<String> hosts;

  /// What was asked, as `connect build`.
  final asked = <String>[];

  /// The refusal the next call gets, once.
  OrganizationRefused? refuseNext;

  void _ask(String what) {
    asked.add(what);
    if (refuseNext case final refused?) {
      refuseNext = null;
      throw refused;
    }
  }

  @override
  bool connected(String host) => hosts.contains(host);

  /// Hosts that say, once connected to, that they wait for a first token; their connection is not up.
  final waiting = <String>{};

  @override
  bool up(String host) => connected(host) && !waiting.contains(host) && !admitting.contains(host);

  @override
  bool waitsForToken(String host) => hosts.contains(host) && waiting.contains(host);

  /// Hosts prepared moments ago that turn the person away until their first follow; their connection is not up.
  final admitting = <String>{};

  @override
  bool waitsForAdmission(String host) => hosts.contains(host) && admitting.contains(host);

  @override
  Future<void> connect(String host) async {
    _ask('connect $host');
    // As Porelo's own connections do: what changed is told once the attempt ran, never in the asking call.
    await Future<void>.value();
    hosts.add(host);
    notifyListeners();
  }

  @override
  Future<void> disconnect(String host) async {
    _ask('disconnect $host');
    hosts.remove(host);
    notifyListeners();
  }

  /// What the host says of itself.
  HostProgress hostProgress = const HostProgress();

  @override
  Future<HostProgress> refresh(String host) async {
    _ask('refresh $host');
    // A machine answers over ssh, never within the call that asked it.
    await Future<void>.value();
    return keepHeard(host, hostProgress);
  }

  @override
  Future<HostProgress> progress(String host) async {
    _ask('progress $host');
    // A machine answers over ssh, never within the call that asked it.
    await Future<void>.value();
    return keepHeard(host, hostProgress);
  }

  /// Why the host offers no start of its read of the organization; null where it offers one.
  String? noFollowNow;

  /// What the host says of itself once it read the organization now; null where the read changes nothing.
  HostProgress? afterFollow;

  @override
  String? whyNotFollowNow(String host) => up(host) ? noFollowNow : 'Connect first.';

  @override
  Future<String> followNow(String host) async {
    _ask('followNow $host');
    // A machine answers over ssh, never within the call that asked it.
    await Future<void>.value();
    if (afterFollow case final after?) hostProgress = after;
    return '$host read the organization.';
  }
}

const _persons = [
  OrganizationPerson(login: 'olive', key: 'SHA256:olive', standing: CardStanding.trusted),
  OrganizationPerson(login: 'hana', key: 'SHA256:hana', standing: CardStanding.trusted),
  OrganizationPerson(login: 'pat', key: 'SHA256:pat', standing: CardStanding.trusted),
  OrganizationPerson(login: 'mia', key: 'SHA256:mia', standing: CardStanding.trusted),
  OrganizationPerson(
    login: 'nora',
    standing: CardStanding.notYet,
    words: 'GitHub not reached, asked again on the next read',
  ),
  OrganizationPerson(login: 'rex', key: 'SHA256:rex', standing: CardStanding.revoked),
];

/// Host `build`, as its card names it.
const buildHost = OrganizationHost(
  name: 'build',
  address: '203.0.113.7',
  port: 22,
  hostKey: 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  webPort: 8081,
  gitPort: 8082,
  matrixPort: 8083,
  admins: ['hana'],
  projects: ['demo'],
);

/// The organization as [me] reads it: olive owns it, hana administers host `build`, pat is the admin of project `demo`
/// and mia a member of it; nora's card could not be asked about and rex's is revoked. `other` has no member of these.
OrganizationView organizationFor(
  String me, {
  List<OrganizationPerson> persons = _persons,
  List<OrganizationProject> moreProjects = const [],
  OrganizationHost host = buildHost,
  bool stale = false,
  List<String> owners = const ['olive'],
  List<String> ownersWithBackup = const [],
  List<String>? organizationAdmins,
  String? forge,
}) => OrganizationView(
  forge: forge,
  stale: stale,
  name: 'acme',
  keptIn: 'the GitHub organization acme',
  vouchedBy: 'GitHub',
  revision: 'r1',
  me: me,
  persons: persons,
  owners: owners,
  ownersWithBackup: ownersWithBackup,
  organizationAdmins: organizationAdmins,
  projects: [
    const OrganizationProject(name: 'demo', admins: ['pat'], members: ['mia'], host: 'build', repositories: 2),
    const OrganizationProject(name: 'other', admins: ['hana']),
    ...moreProjects,
  ],
  hosts: [
    host,
    const OrganizationHost(name: 'spare', admins: ['olive']),
  ],
);

/// Project `demo`: pat is its admin, mia a developer; nora's card could not be asked about, and rex's is revoked.
const demoProject = ProjectView(
  name: 'demo',
  revision: 'p1',
  host: 'build',
  address: 'git@forge.example.org:acme/demo-project.git',
  roles: ['developer', 'admin'],
  repositories: [
    ProjectRepository(name: 'demo', address: 'git@forge.example.org:acme/demo.git'),
    ProjectRepository(name: 'demo-docs', address: 'git@forge.example.org:acme/demo-docs.git'),
  ],
  members: [
    ProjectMember(login: 'pat', role: 'admin', standing: CardStanding.trusted),
    ProjectMember(login: 'mia', role: 'developer', standing: CardStanding.trusted),
    ProjectMember(login: 'nora', role: 'developer', standing: CardStanding.notYet, locked: true),
    ProjectMember(login: 'rex', role: 'developer', standing: CardStanding.revoked),
  ],
);
