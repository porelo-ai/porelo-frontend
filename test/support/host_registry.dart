import 'dart:async';

import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/host_access.dart';
import 'package:porelo_frontend/src/app/host_access_contract.dart';
import 'package:porelo_frontend/src/app/registry.dart';
import 'package:porelo_frontend/src/app/registry_checkout.dart';
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
  'host_key': hostKey,
  'services': {
    'forge': {'web_port': 3000, 'git_port': 3001},
    'matrix': {'port': 8448},
  },
};

class RegistryFixture implements RegistryCore, RegistryCheckout, HostRegistryTransport {
  bool admin = true;
  bool refusedPerson = false;
  bool applyMembership = true;
  bool listedHost = true;
  List<String> assignedAdmins = ['alice'];
  String selectedFingerprint = personFingerprint;
  bool requireStaged = false;
  final staged = <String>{};
  final parents = <String, String>{};
  final signedChanges = <String, HostRegistryChange>{};
  String applied = registryBefore;
  String registryRevision = registryBefore;
  String answerHost = 'orchard';
  String? syncRevision;
  String? fail;
  RegistryRefusal? publicationRefusal;
  Future<void>? holdStatus;
  Future<void>? holdUpload;
  Future<void>? holdFile;
  Completer<void>? fileStarted;
  Completer<void>? uploadStarted;
  Completer<void>? statusStarted;
  final calls = <String>[];
  final changes = <HostRegistryChange>[];
  final filedById = <String, String>{};
  final people = <String, String>{'bob': 'active'};
  late Registry registry;
  HostAdminIdentity? actor = const HostAdminIdentity('alice', adminFingerprint);

  Future<HostAccess> access(Settings settings) async {
    registry = Registry(checkout: this, core: this);
    await registry.refresh();
    return HostAccess(
      registry: registry,
      settings: settings,
      identity: () => actor,
      writer: WriterFixture(this),
      transport: this,
    );
  }

  @override
  String get root => '/private/registry';
  @override
  String get repository => 'git@example.org:team/registry.git';
  @override
  String get folder => '/private/registry/checkout';
  @override
  Future<String> fetch() async => registryBefore;
  @override
  Future<void> prepareFiling() async {}
  @override
  Future<RegistryRead> read(String checkout) async => RegistryRead(
    revision: registryRevision,
    people: [
      const RegistryCard(
        login: 'alice',
        name: 'Alice',
        email: 'alice@example.org',
        key: hostKey,
        fingerprint: adminFingerprint,
        state: 'trusted',
      ),
      RegistryCard(
        login: 'bob',
        name: 'Bob',
        key: hostKey,
        fingerprint: selectedFingerprint,
        state: refusedPerson ? 'refused' : 'trusted',
        why: refusedPerson ? 'Untrusted key' : '',
      ),
    ],
    owners: const [],
    hostAdmins: [if (admin) const RegistryOwner(login: 'alice', fingerprint: adminFingerprint)],
    hosts: [if (listedHost) RegistryHost(host: 'orchard', admins: assignedAdmins)],
  );

  @override
  Future<RegistryFiled> file(String checkout, RegistryFiling filing) => throw UnimplementedError();

  // Dart has no overloads: the host writer is provided through WriterFixture.
  Future<String> fileHost(HostRegistryChange change) async {
    calls.add('file');
    if (fail == 'file') throw Exception('filing refused');
    if (fileStarted?.isCompleted == false) fileStarted!.complete();
    await holdFile;
    if (!filedById.containsKey(change.id)) {
      changes.add(change);
      final revision = (changes.length + 1).toRadixString(16) * 40;
      filedById[change.id] = revision;
      signedChanges[revision] = change;
      parents[revision] = registryRevision;
    }
    return filedById[change.id]!;
  }

  @override
  Future<void> publish(String revision) async {
    calls.add('publish $revision');
    if (publicationRefusal case final refusal?) throw refusal;
    if (fail == 'publish') throw Exception('publication refused');
    registryRevision = revision;
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
    final change = signedChanges[revision];
    if (applyMembership && applied == revision && change?.person != null) {
      final state = switch (change!.action) {
        'admit' || 'unlock' => 'active',
        'lock' => 'locked',
        'purge' => 'purged',
        _ => null,
      };
      if (state != null) people[change.person!] = state;
    }
    return answer();
  }

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

class WriterFixture implements HostRegistryWriter {
  WriterFixture(this.fixture);
  final RegistryFixture fixture;
  @override
  Future<String> file(HostRegistryChange change) => fixture.fileHost(change);
  @override
  Future<void> publish(String revision) => fixture.publish(revision);

  @override
  Future<bool> descendsFrom(String revision, String ancestor) async => fixture.descendsFrom(revision, ancestor);
}
