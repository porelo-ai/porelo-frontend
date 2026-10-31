import 'dart:async';

import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/access_developers.dart';
import 'package:porelo_frontend/src/app/host_access.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/project_access.dart';
import 'package:porelo_frontend/src/app/project_access_contract.dart';
import 'package:porelo_frontend/src/app/registry.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_host/porelo_host.dart';

import 'host_registry.dart';

const projectRevision = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const accessAddress = 'git@example.org:team/access.git';
const projectYaml =
    '''
access:
  repository: $accessAddress
repositories:
  code:
    upstream: https://example.org/team/code.git
''';

class ProjectRegistryFixture extends RegistryFixture {
  bool admitted = true;
  String projectAdmin = 'alice';
  String? rotatedAdminFingerprint;
  String accessRepository = accessAddress;
  @override
  Future<RegistryRead> read(String checkout) async {
    if (fail == 'read') throw const FormatException('registry read refused');
    final base = await super.read(checkout);
    return RegistryRead(
      revision: base.revision,
      people: [
        for (final card in base.people)
          if (card.login == 'alice' && rotatedAdminFingerprint != null)
            RegistryCard(
              login: card.login,
              name: card.name,
              email: card.email,
              key: card.key,
              fingerprint: rotatedAdminFingerprint!,
              state: card.state,
            )
          else
            card,
      ],
      owners: base.owners,
      hosts: [
        RegistryHost(
          host: 'orchard',
          admins: assignedAdmins,
          projects: [
            if (admitted) RegistryProject(name: 'demo', admin: projectAdmin, accessRepository: accessRepository),
          ],
        ),
      ],
    );
  }
}

/// A stateful Core and two-project host stand-in, applying exactly uploaded edits.
class ProjectAccessFixture implements ProjectAccessCore, ProjectAccessTransport {
  final registrySource = ProjectRegistryFixture();
  late final registry = Registry(checkout: registrySource, core: registrySource);
  bool signing = true;
  List<String>? signers;
  HostAdminIdentity actor = const HostAdminIdentity('alice', adminFingerprint);
  Exception? lookupFailure;
  Exception? lookupFailureAfterFile;
  final lookups = <String>[];
  String verifiedRevision = projectRevision;
  Exception? readFailure;
  void Function()? onRead;
  bool failRememberMachine = false;
  bool selfRevokes = false;
  bool deliveryAuthorized = true;
  String? deliveryRevision;
  PreparedHost host = PreparedHost.read(sshCompletion());
  void Function()? onUpload;
  bool authorized = true;
  bool replacement = false;
  bool eligible = true;
  String verifiedProject = 'demo';
  String source = projectYaml;
  String currentAccess = registryBefore;
  String? fail;
  String? wrongProject;
  String? wrongAccess;
  String? wrongProjectRevision;
  Future<void>? holdUpload;
  Completer<void>? uploadStarted;
  FutureOr<void> Function()? onConnect;
  final savedMachines = <Machine>[];
  final calls = <String>[];
  final filed = <String, String>{};
  final changes = <String, ProjectAccessChange>{};
  final uploads = <String>{};
  final published = <String>{};
  final members = <String, AccessDeveloper>{};
  final hostPeople = <String, Map<String, String>>{
    'demo': {},
    'other': {'bob': 'active'},
  };
  final accounts = <String>{'alice', 'bob'};
  final repositories = <String, Set<String>>{
    'demo': {'bob'},
    'other': {'bob'},
  };
  final rooms = <String, Set<String>>{
    'demo': {'bob'},
    'other': {'bob'},
  };

  Future<ProjectAccess> access(Settings settings) async {
    await registry.refresh();
    return ProjectAccess(
      project: 'demo',
      registry: registry,
      settings: settings,
      core: this,
      transport: this,
      rememberMachine: (machine) async {
        if (failRememberMachine) throw const FormatException('machine persistence failed');
        savedMachines.add(machine);
      },
    );
  }

  @override
  Future<ProjectAccessView> read(String project) async {
    onRead?.call();
    if (readFailure case final failure?) throw failure;
    return _view();
  }

  ProjectAccessView _view({String? accessRevision}) {
    return ProjectAccessView(
      project: verifiedProject,
      host: host,
      projectRevision: verifiedRevision,
      accessRevision: accessRevision ?? currentAccess,
      projectYaml: source,
      actor: actor,
      admittedFingerprint: actor.fingerprint,
      canAdmin: authorized,
      signingAvailable: signing,
      adminSigners: signers ?? (authorized ? [hostKey] : []),
      access: AccessDevelopers(members.values),
      eligible: {if (eligible) 'bob': ProjectPersonVerdict(personFingerprint, replacedLostKey: replacement)},
      whoMay: const [RegistryContact(login: 'alice', name: 'Alice', email: 'alice@example.org')],
    );
  }

  @override
  Future<ProjectAccessView> delivery(ProjectAccessChange change, String revision) async {
    if (!deliveryAuthorized || filed[change.id] != revision || changes[revision]?.project != change.project) {
      throw const FormatException('The exact filed change is not authorized for delivery.');
    }
    await read(change.project);
    return _view(accessRevision: deliveryRevision ?? revision);
  }

  @override
  Future<String?> filedRevision(ProjectAccessChange change) async {
    lookups.add(change.id);
    if (lookupFailure case final failure?) throw failure;
    return filed[change.id];
  }

  @override
  Future<String> file(ProjectAccessChange change) async {
    calls.add('file');
    lookupFailure = lookupFailureAfterFile;
    if (fail == 'file') throw const FormatException('signing refused');
    if (filed.containsKey(change.id)) return filed[change.id]!;
    if (change.baseRevision != currentAccess) throw const FormatException('concurrent edit');
    final revision = (filed.length + 2).toRadixString(16) * 40;
    filed[change.id] = revision;
    changes[revision] = change;
    if (fail == 'file-after-commit') {
      currentAccess = revision;
      throw const FormatException('filing reply lost');
    }
    return revision;
  }

  @override
  Future<bool> publishedRevision(ProjectAccessChange change, String revision) async =>
      published.contains(revision) && filed[change.id] == revision && changes[revision]?.id == change.id;

  @override
  Future<void> publish(ProjectAccessChange change, String revision) async {
    calls.add('publish');
    if (fail == 'publish') throw const FormatException('publication refused');
    if (published.add(revision)) {
      if (selfRevokes && change.person?.login == 'alice' && (change.action == 'remove' || change.action == 'lock')) {
        authorized = false;
      }
      currentAccess = revision;
      final person = change.person;
      if (change.action == 'add') members[person!.login] = person;
      if (change.action == 'remove') members.remove(person!.login);
      if (change.action == 'lock' || change.action == 'unlock') {
        members[person!.login] = AccessDeveloper(
          login: person.login,
          role: person.role,
          fingerprint: person.fingerprint,
          locked: change.action == 'lock',
        );
      }
    }
  }

  @override
  Future<Machine> connect(ProjectAccessView view) async {
    calls.add('connect');
    await onConnect?.call();
    return const Machine(
      name: 'alice on orchard',
      kind: 'host',
      hostProject: 'orchard',
      host: 'alice@203.0.113.7',
      socketPath: '/unused',
    );
  }

  @override
  Future<void> upload(ProjectAccessChange change, String accessRevision) async {
    calls.add('upload');
    uploadStarted?.complete();
    await holdUpload;
    if (fail == 'upload') throw const FormatException('upload refused');
    if (!published.contains(accessRevision)) throw const FormatException('not published');
    uploads.add(accessRevision);
    onUpload?.call();
  }

  @override
  Future<ProjectAccessStatus> apply(ProjectAccessChange change, String accessRevision) async {
    calls.add('apply');
    if (fail == 'apply') throw const FormatException('apply refused');
    if (!uploads.remove(accessRevision)) throw const FormatException('no exact intake');
    final selected = changes[accessRevision]!.person;
    final people = hostPeople[change.project]!;
    if (selected != null) {
      if (change.action == 'remove') {
        people.remove(selected.login);
      } else {
        people[selected.login] = change.action == 'lock' ? 'locked' : 'active';
      }
      if (change.action == 'remove' || change.action == 'lock') {
        repositories[change.project]!.remove(selected.login);
        rooms[change.project]!.remove(selected.login);
      } else {
        repositories[change.project]!.add(selected.login);
        rooms[change.project]!.add(selected.login);
      }
    }
    return ProjectAccessStatus(
      host: change.host,
      project: wrongProject ?? change.project,
      projectRevision: wrongProjectRevision ?? change.projectRevision,
      accessRevision: wrongAccess ?? accessRevision,
      people: Map.of(people),
    );
  }
}
