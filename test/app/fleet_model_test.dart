import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/app/fleet_model.dart';

/// A backend that is reachable and useless: the socket opens and nothing is ever answered.
class _Wedged implements FleetBackend {
  @override
  String get label => 'the mock';

  @override
  Future<ServiceInfo> open() async => throw const VarlinkDisconnected('the fake said nothing');

  @override
  Future<List<Task>> tasks() async => const <Task>[];

  @override
  Future<List<Project>> projects() async => const <Project>[];

  @override
  Stream<List<Task>> watch() => const Stream<List<Task>>.empty();

  @override
  Stream<StartEvent> startTask({
    String? task,
    String? project,
    String? agent,
    bool dryRun = false,
    Mode? mode,
    String? prompt,
    String? model,
    int? maxTurns,
    int? minutes,
    String? repository,
    Map<String, String>? credentials,
  }) => const Stream<StartEvent>.empty();

  @override
  Future<Stopped> stopTask(String task) async => throw const VarlinkDisconnected('nothing there');

  @override
  Future<Removed> removeTask(String task, {bool? rescue, bool? force}) async =>
      throw const VarlinkDisconnected('nothing there');

  @override
  Future<StartProgress> startAgain({required String project, required String task, String? repository}) async =>
      throw const VarlinkDisconnected('nothing there');

  @override
  Future<Enrolled> enrollDevice({required String name, required String share, required KeyslotStorage storage}) async =>
      throw const VarlinkDisconnected('nothing there');

  @override
  Future<List<Keyslot>> keyslots() async => throw const VarlinkDisconnected('nothing there');

  @override
  Future<Revoked> revokeKeyslot(String id) async => throw const VarlinkDisconnected('nothing there');

  @override
  Future<UnlockedWithShare> unlockWithShare({required String share, int? minutes}) async =>
      throw const VarlinkDisconnected('nothing there');

  @override
  Future<List<Log>> logsOf(String task) async => const <Log>[];

  @override
  Future<GateState> gateOf(String projectFile, {String? repository}) async => GateState.from(const <String, dynamic>{});

  @override
  Future<({String diff, String log, List<ReviewFile> files, String? asked})> reviewOf(
    String projectFile,
    String name, {
    String? against,
    String? repository,
  }) async => (diff: '', log: '', files: const <ReviewFile>[], asked: null);

  @override
  Future<void> approve(String projectFile, String name, String branch, {String? repository, String? commit}) async {}

  @override
  Future<({bool? told})> reject(String projectFile, String name, {String? repository, String? reason}) async =>
      (told: null);

  @override
  Future<String> tell(String task, String text) async => '';

  @override
  Future<(List<EgressHost>, List<String>)> egressOf(String projectFile, {String? repository}) async =>
      (const <EgressHost>[], const <String>[]);

  @override
  Future<(List<EgressSet>, List<String>)> egressSets() async => (const <EgressSet>[], const <String>[]);

  @override
  Future<EgressChange> changeEgress(
    String projectFile, {
    List<String>? addSets,
    List<String>? removeSets,
    List<String>? addDomains,
    List<String>? removeDomains,
    bool? dryRun,
    String? repository,
  }) async => EgressChange.from(const <String, dynamic>{});

  @override
  Stream<Prompt> prompts() => const Stream<Prompt>.empty();

  @override
  Future<List<HeldMessage>> messagesHeld({String? task}) async => const <HeldMessage>[];

  @override
  Future<HeldMessageRead> readHeld(String task, String id) async =>
      HeldMessageRead.from(const <String, dynamic>{'outcome': 'NO_SUCH_MESSAGE'});

  @override
  Future<MessageRelease> release(String task, String id, {bool refuse = false, String? reason}) async =>
      MessageRelease.from(const <String, dynamic>{'outcome': 'NO_SUCH_MESSAGE'});

  @override
  Stream<TalkEvent> talk() => const Stream<TalkEvent>.empty();

  @override
  Stream<AuthorizeProgress> authorize(String name) => const Stream<AuthorizeProgress>.empty();

  @override
  Stream<AuthorizationNeeded> authorizations() => const Stream<AuthorizationNeeded>.empty();

  @override
  Future<MessagesJoined> joinMessages(String project, String person, {bool reset = false}) async =>
      throw UnimplementedError();

  @override
  Future<List<MessageMember>> messageMembers(String project) async => const <MessageMember>[];

  Future<MachineDeployKey> deployKey(
    String project, {
    String? repository,
    String? upstream,
    bool? readOnly,
    bool renew = false,
  }) async => throw UnimplementedError();

  @override
  Future<MachineKey> messageKey() async => throw UnimplementedError();

  @override
  Future<String> contract() async => '';

  @override
  Future<List<DefaultRepository>> defaultRepositories() async => const <DefaultRepository>[];

  @override
  Future<DefaultRepository> addToDefault(String upstream, {String? name}) async => throw UnimplementedError();

  @override
  Future<({bool removed, List<MachineDeployKey> keys})> removeFromDefault(String name) async =>
      (removed: false, keys: const <MachineDeployKey>[]);

  @override
  Future<({List<int> bundle, int bytes})> pendingBundle(
    String project,
    String name, {
    String? repository,
    String? branch,
  }) async => throw UnimplementedError();

  @override
  Future<({bool landed, String commit, String detail})> landed(
    String project,
    String name, {
    String? repository,
    required String branch,
  }) async => throw UnimplementedError();

  @override
  Future<ProjectFileSchema> projectFileSchema() async => throw UnimplementedError();

  @override
  Future<ProjectFileCheck> checkProjectFile(String text) async => throw UnimplementedError();

  @override
  Future<List<TalkPeer>> peers(String task, String project) async => const <TalkPeer>[];

  @override
  Future<TalkPeer> moderate(String task, String project, String name, {bool? held, String? mode}) async =>
      throw UnimplementedError();

  @override
  Future<Said> say(String task, String peer, String text, {String kind = 'question'}) async =>
      throw UnimplementedError();

  @override
  Future<List<Destination>> destinations() async => const <Destination>[];

  @override
  Future<({Destination destination, bool written})> writeDestination({
    required String name,
    required String upstream,
    String? label,
    String? authHeader,
    String? authPrefix,
    String? authQuery,
    bool dryRun = false,
  }) async => throw UnimplementedError();

  @override
  Future<({bool removed, String file})> removeDestination(String name) async => throw UnimplementedError();

  @override
  Future<void> decide(Prompt prompt, {required bool allow}) async {}

  @override
  Future<Screen> screen(String task, {required int last, bool escapes = false}) async =>
      throw const FeatureNotSupported('Screen');

  @override
  Stream<List<String>> tailLog(String task, String log, {int? last, bool formatted = false}) =>
      const Stream<List<String>>.empty();
  @override
  Future<Widened> widenTask(String task, List<String> domains, {required Scope scope, bool? dryRun}) async =>
      throw UnimplementedError();

  @override
  Future<AgentsOnTheMachine> agentsOn() async =>
      (agents: const <Agent>[], failures: const <String, String>{}, shadowed: const <ShadowedAgent>[]);

  @override
  Future<Panicked> panic({bool? dryRun}) async =>
      const Panicked(tasks: <PanickedTask>[], surviving: <String>[], previewed: false);

  @override
  Future<String> node() async => '';

  @override
  Stream<PrepareProgress> prepare(String project, {String? agent, String? rebuild, bool? dryRun}) =>
      const Stream<PrepareProgress>.empty();

  @override
  Future<ClearanceSet> setClearance(String task, String mode, {bool? dryRun}) async =>
      const ClearanceSet(outcome: 'CHANGED', was: 'prompt', now: 'off', detail: '');

  @override
  Future<Narrowed> narrowTask(String task, List<String> domains, {required Scope scope, bool? dryRun}) async =>
      const Narrowed(outcome: WidenOutcome.widened, closes: <String>[], addresses: 0, persisted: false, detail: '');

  @override
  Future<HeldWork> workHeld(String task) async => const HeldWork(readable: true, changedFiles: 0, unpushedCommits: 0);

  @override
  Future<Synced> syncUpstream(String project, {String? repository}) async =>
      const Synced(outcome: 'MEASURED', behind: 0, measured: true, reason: 'MEASURED', detail: '');

  @override
  Future<List<Followed>> refreshProjects({String? project}) async => const <Followed>[];

  @override
  Future<TaskRefreshed> refreshTask(String task) async => const TaskRefreshed(outcome: 'UNCHANGED');

  @override
  Future<Restored> restoreBackup(
    String project,
    String bundle, {
    bool? dryRun,
    bool? force,
    String? repository,
  }) async => const Restored(outcome: 'RESTORED', mirror: '', unreviewed: <String>[], detail: '');

  @override
  Future<List<Backup>> backups(String project, {String? repository}) async => const <Backup>[];

  @override
  Future<BackupDeleted> deleteBackup(String project, String bundle, {bool? dryRun}) async =>
      const BackupDeleted(outcome: 'DELETED', fileRemoved: true, refs: 0, detail: '');

  @override
  Future<Health> doctor() async => const Health(probes: <Probe>[], ready: true);

  @override
  Future<Providers> providers() async => const Providers(providers: <Provider>[], readable: true);

  @override
  Future<Imported> importCredential({String? agent, String? configDirectory}) async =>
      const Imported(outcome: 'IMPORTED', name: '', type: '', length: 0, source: '', detail: '');

  @override
  Future<Followed> follow(
    String name,
    String url, {
    String? signedBy,
    List<String>? signers,
    bool? unverified,
    bool? acceptRewrite,
  }) async => Followed(name: name, url: url, outcome: 'APPLIED');

  @override
  Future<Cleared> clear({String? project, bool? dryRun, bool? force}) async => const Cleared();

  @override
  Future<CredentialDeclared> credentialDeclare({
    required String kind,
    required String match,
    String? id,
    String? user,
    String? purpose,
    String? source,
    String? fromFile,
    bool? dryRun,
  }) async => CredentialDeclared(
    connection: Connection(kind: kind, match: match),
  );

  @override
  Future<CredentialForgotten> credentialForget(String match) async => const CredentialForgotten(forgotten: true);

  @override
  Future<CredentialChecked> credentialCheck(String url, {String? purpose}) async =>
      const CredentialChecked(outcome: 'READY');

  @override
  Future<List<SshKey>> sshKeys() async => const <SshKey>[];

  @override
  Future<HostKeyTrusted> trustHostKey(String host, String fingerprint) async => const HostKeyTrusted();

  @override
  Future<Deletion> unfollow(String project, {bool? dryRun, bool? force}) async => const Deletion(
    outcome: DeleteOutcome.deleted,
    removes: <Removal>[],
    keeps: <String>[],
    unreviewed: <String>[],
    running: <String>[],
    detail: '',
  );

  @override
  Future<Readiness> canStart({
    String? project,
    String? agent,
    String? task,
    String? repository,
    Map<String, String>? credentials,
  }) async =>
      const Readiness(ready: true, outcome: StartOutcome.ready, agent: '', provider: '', credential: '', detail: '');

  @override
  Future<VaultState> credentials() async => VaultState.from(const <String, dynamic>{});

  @override
  Future<Locked> lock() async => const Locked(keyring: true, wasCached: false, holding: 0);

  @override
  Future<Labelled> labelTask(String task, {String? label}) async => const Labelled(outcome: 'LABELLED', label: '');

  @override
  Future<HandInPart> handIn(
    String task, {
    required String name,
    required int bytes,
    required String sha256,
    required int offset,
    required List<int> part,
  }) async => throw const FeatureNotSupported('HandIn');

  @override
  Future<HandedFile> takeBack(String task, String name) async => throw const FeatureNotSupported('TakeBack');

  @override
  Future<List<HandInEvent>> handIns(String task) async => throw const FeatureNotSupported('HandIns');
}

/// A machine that lists one project nothing has ever run on, and one task belonging to a project
/// it does not list at all.
class _Machine implements FleetBackend {
  @override
  String get label => 'the mock';

  @override
  Future<ServiceInfo> open() async =>
      const ServiceInfo(product: 'Porelo', version: '0', vendor: 'fuin.org', interfaces: <String>[]);

  @override
  Future<List<Task>> tasks() async => <Task>[
    Task.from(const <String, dynamic>{'name': 'porelo-orphan', 'project': 'vanished'}),
  ];

  @override
  Future<List<Project>> projects() async => <Project>[
    Project.from(const <String, dynamic>{'name': 'never-run', 'tasks': 0}),
    // Counts that do not match what List returned, on purpose: the daemon assembles them from
    // the mirrors and the tasks that exist, and knows about work this end has not matched.
    Project.from(const <String, dynamic>{'name': 'busy', 'tasks': 7, 'running': 3}),
  ];

  @override
  Stream<List<Task>> watch() => const Stream<List<Task>>.empty();

  @override
  Stream<StartEvent> startTask({
    String? task,
    String? project,
    String? agent,
    bool dryRun = false,
    Mode? mode,
    String? prompt,
    String? model,
    int? maxTurns,
    int? minutes,
    String? repository,
    Map<String, String>? credentials,
  }) => const Stream<StartEvent>.empty();

  @override
  Future<Stopped> stopTask(String task) async => throw UnimplementedError();

  @override
  Future<Removed> removeTask(String task, {bool? rescue, bool? force}) async => throw UnimplementedError();

  @override
  Future<StartProgress> startAgain({required String project, required String task, String? repository}) async =>
      throw UnimplementedError();

  @override
  Future<Enrolled> enrollDevice({required String name, required String share, required KeyslotStorage storage}) async =>
      throw UnimplementedError();

  @override
  Future<List<Keyslot>> keyslots() async => throw UnimplementedError();

  @override
  Future<Revoked> revokeKeyslot(String id) async => throw UnimplementedError();

  @override
  Future<UnlockedWithShare> unlockWithShare({required String share, int? minutes}) async => throw UnimplementedError();

  @override
  Future<List<Log>> logsOf(String task) async => const <Log>[];

  @override
  Future<GateState> gateOf(String projectFile, {String? repository}) async => GateState.from(const <String, dynamic>{});

  @override
  Future<({String diff, String log, List<ReviewFile> files, String? asked})> reviewOf(
    String projectFile,
    String name, {
    String? against,
    String? repository,
  }) async => (diff: '', log: '', files: const <ReviewFile>[], asked: null);

  @override
  Future<void> approve(String projectFile, String name, String branch, {String? repository, String? commit}) async {}

  @override
  Future<({bool? told})> reject(String projectFile, String name, {String? repository, String? reason}) async =>
      (told: null);

  @override
  Future<String> tell(String task, String text) async => '';

  @override
  Stream<Prompt> prompts() => const Stream<Prompt>.empty();

  @override
  Future<List<HeldMessage>> messagesHeld({String? task}) async => const <HeldMessage>[];

  @override
  Future<HeldMessageRead> readHeld(String task, String id) async =>
      HeldMessageRead.from(const <String, dynamic>{'outcome': 'NO_SUCH_MESSAGE'});

  @override
  Future<MessageRelease> release(String task, String id, {bool refuse = false, String? reason}) async =>
      MessageRelease.from(const <String, dynamic>{'outcome': 'NO_SUCH_MESSAGE'});

  @override
  Stream<TalkEvent> talk() => const Stream<TalkEvent>.empty();

  @override
  Stream<AuthorizeProgress> authorize(String name) => const Stream<AuthorizeProgress>.empty();

  @override
  Stream<AuthorizationNeeded> authorizations() => const Stream<AuthorizationNeeded>.empty();

  @override
  Future<MessagesJoined> joinMessages(String project, String person, {bool reset = false}) async =>
      throw UnimplementedError();

  @override
  Future<List<MessageMember>> messageMembers(String project) async => const <MessageMember>[];

  Future<MachineDeployKey> deployKey(
    String project, {
    String? repository,
    String? upstream,
    bool? readOnly,
    bool renew = false,
  }) async => throw UnimplementedError();

  @override
  Future<MachineKey> messageKey() async => throw UnimplementedError();

  @override
  Future<String> contract() async => '';

  @override
  Future<List<DefaultRepository>> defaultRepositories() async => const <DefaultRepository>[];

  @override
  Future<DefaultRepository> addToDefault(String upstream, {String? name}) async => throw UnimplementedError();

  @override
  Future<({bool removed, List<MachineDeployKey> keys})> removeFromDefault(String name) async =>
      (removed: false, keys: const <MachineDeployKey>[]);

  @override
  Future<({List<int> bundle, int bytes})> pendingBundle(
    String project,
    String name, {
    String? repository,
    String? branch,
  }) async => throw UnimplementedError();

  @override
  Future<({bool landed, String commit, String detail})> landed(
    String project,
    String name, {
    String? repository,
    required String branch,
  }) async => throw UnimplementedError();

  @override
  Future<ProjectFileSchema> projectFileSchema() async => throw UnimplementedError();

  @override
  Future<ProjectFileCheck> checkProjectFile(String text) async => throw UnimplementedError();

  @override
  Future<List<TalkPeer>> peers(String task, String project) async => const <TalkPeer>[];

  @override
  Future<TalkPeer> moderate(String task, String project, String name, {bool? held, String? mode}) async =>
      throw UnimplementedError();

  @override
  Future<Said> say(String task, String peer, String text, {String kind = 'question'}) async =>
      throw UnimplementedError();

  @override
  Future<List<Destination>> destinations() async => const <Destination>[];

  @override
  Future<({Destination destination, bool written})> writeDestination({
    required String name,
    required String upstream,
    String? label,
    String? authHeader,
    String? authPrefix,
    String? authQuery,
    bool dryRun = false,
  }) async => throw UnimplementedError();

  @override
  Future<({bool removed, String file})> removeDestination(String name) async => throw UnimplementedError();

  @override
  Future<void> decide(Prompt prompt, {required bool allow}) async {}
  @override
  Future<(List<EgressHost>, List<String>)> egressOf(String projectFile, {String? repository}) async =>
      (const <EgressHost>[], const <String>[]);

  @override
  Future<(List<EgressSet>, List<String>)> egressSets() async => (const <EgressSet>[], const <String>[]);

  @override
  Future<EgressChange> changeEgress(
    String projectFile, {
    List<String>? addSets,
    List<String>? removeSets,
    List<String>? addDomains,
    List<String>? removeDomains,
    bool? dryRun,
    String? repository,
  }) async => EgressChange.from(const <String, dynamic>{});

  @override
  Future<Screen> screen(String task, {required int last, bool escapes = false}) async =>
      throw const FeatureNotSupported('Screen');

  @override
  Stream<List<String>> tailLog(String task, String log, {int? last, bool formatted = false}) =>
      const Stream<List<String>>.empty();
  @override
  Future<Widened> widenTask(String task, List<String> domains, {required Scope scope, bool? dryRun}) async =>
      throw UnimplementedError();

  @override
  Future<AgentsOnTheMachine> agentsOn() async =>
      (agents: const <Agent>[], failures: const <String, String>{}, shadowed: const <ShadowedAgent>[]);

  @override
  Future<Panicked> panic({bool? dryRun}) async =>
      const Panicked(tasks: <PanickedTask>[], surviving: <String>[], previewed: false);

  @override
  Future<String> node() async => '';

  @override
  Stream<PrepareProgress> prepare(String project, {String? agent, String? rebuild, bool? dryRun}) =>
      const Stream<PrepareProgress>.empty();

  @override
  Future<ClearanceSet> setClearance(String task, String mode, {bool? dryRun}) async =>
      const ClearanceSet(outcome: 'CHANGED', was: 'prompt', now: 'off', detail: '');

  @override
  Future<Narrowed> narrowTask(String task, List<String> domains, {required Scope scope, bool? dryRun}) async =>
      const Narrowed(outcome: WidenOutcome.widened, closes: <String>[], addresses: 0, persisted: false, detail: '');

  @override
  Future<HeldWork> workHeld(String task) async => const HeldWork(readable: true, changedFiles: 0, unpushedCommits: 0);

  @override
  Future<Synced> syncUpstream(String project, {String? repository}) async =>
      const Synced(outcome: 'MEASURED', behind: 0, measured: true, reason: 'MEASURED', detail: '');

  @override
  Future<List<Followed>> refreshProjects({String? project}) async => const <Followed>[];

  @override
  Future<TaskRefreshed> refreshTask(String task) async => const TaskRefreshed(outcome: 'UNCHANGED');

  @override
  Future<Restored> restoreBackup(
    String project,
    String bundle, {
    bool? dryRun,
    bool? force,
    String? repository,
  }) async => const Restored(outcome: 'RESTORED', mirror: '', unreviewed: <String>[], detail: '');

  @override
  Future<List<Backup>> backups(String project, {String? repository}) async => const <Backup>[];

  @override
  Future<BackupDeleted> deleteBackup(String project, String bundle, {bool? dryRun}) async =>
      const BackupDeleted(outcome: 'DELETED', fileRemoved: true, refs: 0, detail: '');

  @override
  Future<Health> doctor() async => const Health(probes: <Probe>[], ready: true);

  @override
  Future<Providers> providers() async => const Providers(providers: <Provider>[], readable: true);

  @override
  Future<Imported> importCredential({String? agent, String? configDirectory}) async =>
      const Imported(outcome: 'IMPORTED', name: '', type: '', length: 0, source: '', detail: '');

  @override
  Future<Followed> follow(
    String name,
    String url, {
    String? signedBy,
    List<String>? signers,
    bool? unverified,
    bool? acceptRewrite,
  }) async => Followed(name: name, url: url, outcome: 'APPLIED');

  @override
  Future<Cleared> clear({String? project, bool? dryRun, bool? force}) async => const Cleared();

  @override
  Future<CredentialDeclared> credentialDeclare({
    required String kind,
    required String match,
    String? id,
    String? user,
    String? purpose,
    String? source,
    String? fromFile,
    bool? dryRun,
  }) async => CredentialDeclared(
    connection: Connection(kind: kind, match: match),
  );

  @override
  Future<CredentialForgotten> credentialForget(String match) async => const CredentialForgotten(forgotten: true);

  @override
  Future<CredentialChecked> credentialCheck(String url, {String? purpose}) async =>
      const CredentialChecked(outcome: 'READY');

  @override
  Future<List<SshKey>> sshKeys() async => const <SshKey>[];

  @override
  Future<HostKeyTrusted> trustHostKey(String host, String fingerprint) async => const HostKeyTrusted();

  @override
  Future<Deletion> unfollow(String project, {bool? dryRun, bool? force}) async => const Deletion(
    outcome: DeleteOutcome.deleted,
    removes: <Removal>[],
    keeps: <String>[],
    unreviewed: <String>[],
    running: <String>[],
    detail: '',
  );

  @override
  Future<Readiness> canStart({
    String? project,
    String? agent,
    String? task,
    String? repository,
    Map<String, String>? credentials,
  }) async =>
      const Readiness(ready: true, outcome: StartOutcome.ready, agent: '', provider: '', credential: '', detail: '');

  @override
  Future<VaultState> credentials() async => VaultState.from(const <String, dynamic>{});

  @override
  Future<Locked> lock() async => const Locked(keyring: true, wasCached: false, holding: 0);

  @override
  Future<Labelled> labelTask(String task, {String? label}) async => const Labelled(outcome: 'LABELLED', label: '');

  @override
  Future<HandInPart> handIn(
    String task, {
    required String name,
    required int bytes,
    required String sha256,
    required int offset,
    required List<int> part,
  }) async => throw const FeatureNotSupported('HandIn');

  @override
  Future<HandedFile> takeBack(String task, String name) async => throw const FeatureNotSupported('TakeBack');

  @override
  Future<List<HandInEvent>> handIns(String task) async => throw const FeatureNotSupported('HandIns');
}

/// A backend that answers nothing, for a test that must not reach one.
final aBackendThatRefusesEverything = _Machine();

/// A backend whose socket answers only when the test says so.
class _Slow extends _Wedged {
  final Completer<void> answer = Completer<void>();

  @override
  Future<ServiceInfo> open() async {
    await answer.future;
    return super.open();
  }
}

class _StopReply extends _Wedged {
  _StopReply(this.reply);

  final Map<String, dynamic> reply;

  @override
  Future<Stopped> stopTask(String task) async => Stopped.from(reply);
}

void main() {
  // Harm: hiding a surviving helper in the frame leaves it running without an actionable name.
  test('the frame reports the helper that outlived a stop by name', () async {
    final fleet = FleetModel(
      _StopReply({
        'outcome': 'STOPPED',
        'surviving': ['porelo-x-proxy'],
      }),
    );
    addTearDown(fleet.dispose);

    await fleet.stopWork('porelo-demo-shell-1');

    expect(
      fleet.saidAbout('porelo-demo-shell-1'),
      allOf(
        contains('One helper outlived the stop'),
        contains('porelo-x-proxy'),
        contains('killed on the machine by hand'),
      ),
    );
  });

  for (final sample in <String, Map<String, dynamic>>{
    'a string': {'surviving': '0'},
    'a map': {'surviving': <String, dynamic>{}},
    'an absent field': {},
  }.entries) {
    // Harm: the frame must not present an unreported helper count as a confirmed clean stop.
    test('the frame warns that survivors are not reported for ${sample.key}', () async {
      final fleet = FleetModel(_StopReply({'outcome': 'STOPPED', ...sample.value}));
      addTearDown(fleet.dispose);

      await fleet.stopWork('porelo-demo-shell-1');

      expect(fleet.saidAbout('porelo-demo-shell-1'), contains('not reported'));
      expect(fleet.saidAbout('porelo-demo-shell-1'), isNot(contains('clean')));
    });
  }

  // What asks a machine just added waits for this, rather than a socket that is not open yet.
  test('waiting until a machine was asked ends only once connecting is over', () async {
    final backend = _Slow();
    final fleet = FleetModel(backend);
    unawaited(fleet.connect());
    var over = false;
    unawaited(fleet.untilAsked().then((_) => over = true));
    // Something else changing meanwhile is not the end of connecting.
    fleet.say('something else happened');
    await Future<void>.delayed(Duration.zero);
    expect(over, isFalse, reason: 'it ended while the machine was still being connected to');

    backend.answer.complete();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(over, isTrue);
    expect(fleet.reachability, Reachability.unreachable);
    fleet.dispose();
  });

  test('a backend that never answers reads as not connected, and says why', () async {
    // Otherwise the frame sits on "asking the backend what is here" for ever, which is the one
    // state a person can neither act on nor understand.
    final fleet = FleetModel(_Wedged());

    await fleet.connect();

    expect(fleet.reachability, Reachability.unreachable);
    // The model's own sentence around the reason, which is the only part the fake supplies.
    expect(fleet.status, 'Cannot reach the mock: the fake said nothing');
    fleet.dispose();
  });

  test('connecting again does not hear the same question twice', () async {
    // A dropped tunnel reconnects; every reconnect listening once more would redraw the whole
    // frame once more for every question, for as long as the window is open.
    final fleet = FleetModel(_Machine());
    await fleet.connect();
    await fleet.connect();
    var heard = 0;
    fleet.addListener(() => heard++);

    fleet.clearance.forget(Prompt.from(const <String, dynamic>{'task': 't', 'key': 'k'}));

    expect(heard, 1);
    fleet.dispose();
  });

  test('a project that has never run anything is listed, and so is orphaned work', () async {
    // Two things a derived list gets wrong in opposite directions: it cannot show a project with
    // no tasks at all, and it would silently drop work whose project the daemon no longer lists.
    final fleet = FleetModel(_Machine());

    await fleet.connect();

    expect(fleet.projects.map((project) => project.name), containsAll(<String>['never-run', 'vanished']));
    final vanished = fleet.projects.firstWhere((project) => project.name == 'vanished');
    expect(vanished.tasks, hasLength(1));
    expect(vanished.canBeActedOn, isFalse);
    fleet.dispose();
  });

  test('how much work a project has is the daemon count, not one made up here', () async {
    // Projects lists every project, not only the busy ones, and gives both numbers rather than
    // leaving one to be inferred. Counting the tasks this end happened to match would report
    // nothing for a project whose work it could not pair up.
    final fleet = FleetModel(_Machine());

    await fleet.connect();

    final busy = fleet.projects.firstWhere((project) => project.name == 'busy');
    expect(busy.howMuchWork, 7);
    expect(busy.running, 3);
    expect(busy.tasks, isEmpty);
    fleet.dispose();
  });
}
