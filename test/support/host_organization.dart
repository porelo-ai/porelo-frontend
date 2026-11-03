import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_access.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/app/settings.dart';

const adminFingerprint = 'SHA256:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const personFingerprint = 'SHA256:BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB';
const hostKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcH';
const backupKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI';
const forgeLine = 'forge.example.org ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJ';

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

/// The organization as `porelo org` answers it, stating the contract's fields: alice is host admin of [adminHosts].
class HostFixture implements OrganizationSource {
  bool admin = true;

  /// The projects the organization says stand on orchard.
  List<String> orchardProjects = const [];

  /// Whether alice is an Organization Admin, by being its owner while no list exists.
  bool organizationAdmin = false;
  Set<String> adminHosts = {'orchard', 'demo'};
  bool stale = false;
  String revision = '56420b3';
  String? readRefusal;
  String? writeRefusal;
  String knownHosts = forgeLine;

  /// The card the organization holds for the person acting.
  OrganizationPerson card = const OrganizationPerson(
    login: 'alice',
    standing: CardStanding.trusted,
    key: adminFingerprint,
  );

  /// What `porelo org` answers of where the organization is, for a host to follow it.
  String? settings = 'the unread settings';
  String? forge = 'forge.example.org';
  String? address;
  HostAdminIdentity? actor = const HostAdminIdentity('alice', adminFingerprint, hostKey);
  final writes = <OrganizationWrite>[];

  /// What the organization's card of orchard says of the host; empty until its host admin entered it.
  String? cardAddress;
  int? cardPort;
  String? cardHostKey;
  int? cardWebPort;

  /// The other persons the organization answers, beside [card].
  List<OrganizationPerson> others = const [];

  /// The rows of a host's admins, as `hosts[].admins` holds them.
  List<HostAdminKey> keys = const [HostAdminKey(login: 'alice', key: hostKey)];

  /// What `up` was handed, by file path: a widget test's clock never ends real file work, so it keeps no real file.
  final machineFiles = <String, String>{};

  Future<HostAccess> access(Settings settings, {HostAdminProof? proof, bool realFiles = false}) async {
    final scratch = Directory.systemTemp.createTempSync('porelo-host-setup-');
    addTearDown(() => scratch.deleteSync(recursive: true));
    final access = HostAccess(
      source: this,
      identity: () => actor,
      scratch: scratch.path,
      proof: proof,
      knownHosts: () async => knownHosts,
      keepFile: realFiles ? null : (file, text) async => machineFiles[file.path] = text,
    );
    // A held proof is released by its test, which awaits nothing until then.
    if (proof is FixtureProof && proof.hold != null) {
      unawaited(access.readAgain());
    } else {
      await access.readAgain();
    }
    return access;
  }

  @override
  Future<OrganizationView> read() async {
    if (readRefusal case final words?) throw OrganizationRefused(words);
    return OrganizationView(
      name: 'acme',
      keptIn: 'the GitHub organization acme',
      vouchedBy: 'GitHub',
      settings: settings,
      forge: forge,
      address: address,
      revision: revision,
      stale: stale,
      me: 'alice',
      owners: organizationAdmin ? const ['alice'] : const ['mia'],
      persons: [card, ...others],
      hosts: [
        for (final host in {'orchard', 'demo', ...adminHosts})
          OrganizationHost(
            name: host,
            projects: host == 'orchard' ? orchardProjects : const [],
            address: host == 'orchard' ? cardAddress : null,
            port: host == 'orchard' ? cardPort : null,
            hostKey: host == 'orchard' ? cardHostKey : null,
            webPort: host == 'orchard' ? cardWebPort : null,
            admins: admin && adminHosts.contains(host) ? const ['alice'] : const ['hank'],
            adminKeys: keys,
          ),
      ],
    );
  }

  @override
  Future<void> apply(OrganizationWrite write) async {
    writes.add(write);
    if (writeRefusal case final words?) throw OrganizationRefused(words);
  }

  @override
  Future<ProjectView> readProject(String project) => throw UnimplementedError();

  @override
  Future<ProjectInitDraft> readProjectInit(String checkout, {String? project, String? name}) async =>
      throw const OrganizationRefused('No checkout draft was supplied.');

  @override
  Future<List<OrganizationKey>> myKeys() async => const [];

  @override
  Future<List<ListedProject>> myProjects() async => const [];
}

/// Porelo's proven identity as the fixture's [HostFixture.actor]: each read answers [next], after [hold] if set.
class FixtureProof extends ChangeNotifier implements HostAdminProof {
  FixtureProof(this.fixture) : next = fixture.actor;
  final HostFixture fixture;
  HostAdminIdentity? next;
  Completer<void>? hold;
  int reads = 0;

  @override
  Future<void> readAgain() async {
    reads++;
    await hold?.future;
    fixture.actor = next;
    notifyListeners();
  }

  @override
  String? get whyNone => fixture.actor == null ? 'Your key is revoked.' : null;
}
