import 'dart:async';
import 'dart:convert';

import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/host_access.dart';
import 'package:porelo_frontend/src/app/host_access_contract.dart';
import 'package:porelo_frontend/src/app/registry.dart';
import 'package:porelo_frontend/src/app/registry_checkout.dart';
import 'package:porelo_frontend/src/app/run_here.dart' show WorkspaceRefused;
import 'package:porelo_frontend/src/app/settings.dart';

const registryBefore = '1111111111111111111111111111111111111111';
const registryAfter = '2222222222222222222222222222222222222222';
const adminFingerprint = 'SHA256:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const personFingerprint = 'SHA256:BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB';
const hostKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcH';
Map<String, Object?> sshCompletion() => {
  'name': 'orchard',
  'address': '203.0.113.7',
  'ssh_port': 22,
  'ssh_host_key': hostKey,
  'services': {
    'forge': {'web_port': 3000, 'git_port': 3001},
    'matrix': {'port': 8448},
  },
};

/// One commit Core made for a filing, read back from the file it carries.
class FiledChange {
  FiledChange(this.filing, this.revision);
  final RegistryFiling filing;
  final String revision;

  String get action => filing.kind == RegistryFilingKind.hostCard ? 'host-card' : 'admit';
  String? get person => filing.person;
  String? get id => filing.id;
  String? get base => filing.base;
  String get content => filing.content!;
  String? _value(String key) {
    final found = RegExp('${RegExp.escape(key)}: ("[^"\n]*"|[0-9]+)').allMatches(content).lastOrNull?.group(1);
    return found == null ? null : '${jsonDecode(found)}';
  }

  String? get fingerprint => person == null ? null : _value('"$person"');
  String? get project => _value('- name');
  String? get accessRepository => _value('access_repository');

  /// The host card's fields in the completion's shape.
  Map<String, Object?> get card => {
    'name': _value('host'),
    'address': _value('address'),
    'ssh_port': int.parse(_value('ssh_port')!),
    'ssh_host_key': _value('ssh_host_key'),
    'services': {
      'forge': {'web_port': int.parse(_value('web_port')!), 'git_port': int.parse(_value('git_port')!)},
      'matrix': {'port': int.parse(_value('    port')!)},
    },
  };
}

/// Core, the checkout and the host's intake at once: `--id` on the same `--base` answers the same commit.
class RegistryFixture implements RegistryCore, RegistryCheckout, HostRegistryTransport {
  bool admin = true;

  /// The hosts owners.yml names alice as host admin of, while [admin] holds.
  Set<String> adminHosts = {'orchard', 'demo'};
  bool refusedPerson = false;
  bool applyMembership = true;
  bool listedHost = true;
  String selectedFingerprint = personFingerprint;
  bool requireStaged = false;
  final staged = <String>{};
  final parents = <String, String>{};

  /// The host admins a project-access fixture lists for its own host; this fixture answers [pins].
  List<String> assignedAdmins = ['alice'];

  /// The admitted admins `access.yml` pins, `hosts[].admins` in Core's answer.
  final pins = <String, String>{};
  final projects = <RegistryProject>[];
  String applied = registryBefore;
  String registryRevision = registryBefore;
  String answerHost = 'orchard';
  String? syncRevision;
  String? fail;
  String? unpublished;
  RegistryRefusal? publicationRefusal;
  Future<void>? holdStatus;
  Future<void>? holdUpload;
  Completer<void>? uploadStarted;
  Completer<void>? statusStarted;
  final calls = <String>[];
  final changes = <FiledChange>[];
  final _commits = <String, FiledChange>{};
  final people = <String, String>{'bob': 'active'};
  late Registry registry;
  HostAdminIdentity? actor = const HostAdminIdentity('alice', adminFingerprint);

  Future<HostAccess> access(Settings settings) async {
    registry = Registry(checkout: this, core: this);
    await registry.refresh();
    return HostAccess(registry: registry, settings: settings, identity: () => actor, transport: this);
  }

  @override
  String get root => '/private/registry';
  @override
  String get repository => 'git@example.org:team/registry.git';
  @override
  String get folder => '/private/registry/checkout';
  @override
  Future<String> fetch() async => registryRevision;
  @override
  Future<void> prepareFiling() async {
    if (unpublished != null) throw const WorkspaceRefused('The registry checkout holds an unpublished change.');
  }

  /// The accepted host card, as `registry read` answers `hosts[].card`, or null before one was filed.
  Map<String, Object?>? hostCard;

  /// Core's `registry read --json` answer, read through the same parser as the real one.
  @override
  Future<RegistryRead> read(String checkout) async => RegistryRead.from(<String, dynamic>{
    'revision': registryRevision,
    'refused_commit': null,
    'people': [
      {
        'login': 'alice',
        'name': 'Alice',
        'email': 'alice@example.org',
        'key': hostKey,
        'fingerprint': adminFingerprint,
        'state': 'trusted',
        'why': null,
      },
      {
        'login': 'bob',
        'name': 'Bob',
        'email': null,
        'key': hostKey,
        'fingerprint': selectedFingerprint,
        'state': refusedPerson ? 'refused' : 'trusted',
        'why': refusedPerson ? 'Untrusted key' : null,
      },
    ],
    'owners': <Object?>[],
    'host_admins': {
      if (admin)
        for (final host in adminHosts)
          host: [
            {'login': 'alice', 'fingerprint': adminFingerprint, 'backup': false},
          ],
    },
    'warnings': <Object?>[],
    'hosts': [
      if (listedHost)
        {
          'host': 'orchard',
          'card': hostCard,
          'admins': [
            for (final MapEntry(:key, :value) in pins.entries) {'login': key, 'fingerprint': value},
          ],
          'projects': [
            for (final each in projects)
              {'name': each.name, 'admin': each.admin, 'access_repository': each.accessRepository},
          ],
        },
    ],
  });

  @override
  Future<RegistryFiled> file(String checkout, RegistryFiling filing) async {
    calls.add('file');
    if (fail == 'file') throw const VarlinkException('org.fuin.porelo.Registry1.Refused');
    if (filing.base != registryRevision) throw const VarlinkException('org.fuin.porelo.Registry1.BaseMoved');
    final key = '${filing.id}@${filing.base}';
    if (_commits[key] case final known?) return RegistryFiled(revision: known.revision);
    final current = changes.where((each) => each.revision == registryRevision).firstOrNull;
    if (current != null && current.filing.kind == filing.kind && current.content == filing.content) {
      throw const VarlinkException('org.fuin.porelo.Registry1.AlreadyAccepted');
    }
    final revision = (changes.length + 2).toRadixString(16) * 40;
    final change = FiledChange(filing, revision);
    changes.add(change);
    _commits[key] = change;
    parents[revision] = registryRevision;
    unpublished = revision;
    return RegistryFiled(revision: revision);
  }

  /// What a person's own `git push` of the unpublished commit does.
  void pushByHand() {
    final revision = unpublished!;
    unpublished = null;
    _accept(revision);
  }

  void _accept(String revision) {
    registryRevision = revision;
    final change = changes.firstWhere((each) => each.revision == revision);
    if (change.action == 'host-card') {
      final card = change.card;
      hostCard = {
        'host': card['name'],
        'address': card['address'],
        'ssh_port': card['ssh_port'],
        'ssh_host_key': card['ssh_host_key'],
        'services': card['services'],
        'signed_by': adminFingerprint,
      };
    }
    if (change.action == 'admit') {
      pins[change.person!] = change.fingerprint!;
      projects.add(
        RegistryProject(name: change.project!, admin: change.person!, accessRepository: change.accessRepository!),
      );
    }
  }

  @override
  Future<void> publish(String revision) async {
    calls.add('publish $revision');
    if (publicationRefusal case final refusal?) throw refusal;
    if (fail == 'publish') throw const WorkspaceRefused('publication refused');
    unpublished = null;
    _accept(revision);
  }

  @override
  Future<void> upload(String host, String revision) async {
    calls.add('upload $host $revision');
    if (fail == 'upload') throw Exception('registry intake refused');
    if (uploadStarted?.isCompleted == false) uploadStarted!.complete();
    await holdUpload;
    staged.add(revision);
  }

  @override
  Future<HostRegistryStatus> sync(String host, String revision) async {
    calls.add('sync $host $revision');
    if (fail == 'sync') throw Exception('sync refused');
    if (requireStaged && !staged.remove(revision)) throw Exception('staged registry missing');
    if (!descendsFrom(revision, applied)) throw Exception('older or forked registry refused');
    applied = syncRevision ?? revision;
    final change = changes.where((each) => each.revision == revision).firstOrNull;
    if (applyMembership && applied == revision && change?.action == 'admit') people[change!.person!] = 'active';
    return answer();
  }

  /// The host's own ancestry check of its intake.
  bool descendsFrom(String revision, String ancestor) {
    final seen = <String>{};
    for (String? cursor = revision; cursor != null && seen.add(cursor); cursor = parents[cursor]) {
      if (cursor == ancestor) return true;
    }
    return false;
  }

  HostRegistryStatus answer() =>
      HostRegistryStatus(host: answerHost, revision: applied, people: Map.of(people), words: 'Host result.');
  @override
  Future<HostRegistryStatus> status(String host) async {
    calls.add('status $host');
    if (statusStarted?.isCompleted == false) statusStarted!.complete();
    await holdStatus;
    return answer();
  }
}
