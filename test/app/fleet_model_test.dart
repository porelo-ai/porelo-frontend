import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/app/fleet_model.dart';
import 'package:porelo_frontend/src/app/start_refusals.dart';
import 'package:porelo_frontend/src/wire/limit_factors.dart';

/// A backend that is reachable and useless: the socket opens and nothing is ever answered.
class _Wedged implements FleetBackend {
  @override
  Future<TakenProject> takeProject(String project) async => const TakenProject();

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
    bool? now,
    String? from,
  }) => const Stream<StartEvent>.empty();

  @override
  Future<Stopped> stopTask(String task) async => throw const VarlinkDisconnected('nothing there');

  @override
  Future<Removed> removeTask(String task, {bool? rescue, bool? force}) async =>
      throw const VarlinkDisconnected('nothing there');

  @override
  Future<StartProgress> startDiscussion({
    required String project,
    required String agent,
    required String model,
    required Mode mode,
    required String prompt,
    required StartParts parts,
    String? callerKey,
    void Function(StartEvent event)? onEvent,
  }) => throw UnimplementedError();

  @override
  Future<TaskResult> taskResult(String task) => throw UnimplementedError();

  @override
  Future<TaskReports> taskReports(String task, {int? after}) => throw UnimplementedError();

  @override
  Future<String?> whyNoDiscussion() => throw UnimplementedError();

  @override
  Future<StartProgress> startOrdered({
    required String project,
    required String repository,
    required String agent,
    required String model,
    required Mode mode,
    required String prompt,
    required StartParts parts,
    String? callerKey,
    void Function(StartEvent event)? onEvent,
    String? result,
    Map<String, String> given = const {},
    TrackedWork? work,
    String? task,
  }) async => throw const VarlinkDisconnected('nothing there');

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
  Future<PushReview> reviewOf(
    String projectFile,
    String name, {
    String? against,
    String? repository,
    bool? ignoreLineEndings,
  }) async => const PushReview();

  @override
  Future<ReviewPage> reviewPageOf(
    String projectFile,
    String name, {
    String? repository,
    required String commit,
    required String against,
    required bool ignoreLineEndings,
    required String part,
    required int from,
  }) async => (files: null, commits: null, text: null, next: null);

  @override
  Future<ReviewSummary> reviewSummaryOf(
    String projectFile,
    String name, {
    String? repository,
    required String commit,
  }) => throw const FeatureNotSupported('ReviewSummary');

  @override
  Future<ForwardedPush> approve(
    String projectFile,
    String name,
    String branch, {
    String? repository,
    String? commit,
  }) async => ForwardedPush(forwarded: name, branch: branch);

  @override
  Future<TriedPush> credentialTryPush(
    String project, {
    String? repository,
    required String refspec,
    required String source,
    required String id,
  }) async => throw UnimplementedError();

  @override
  Future<({bool? told})> reject(String projectFile, String name, {String? repository, String? reason}) async =>
      (told: null);

  @override
  Future<PushEnd> pushEnd(String projectFile, String name, {String? repository}) async => throw UnimplementedError();

  @override
  Future<String> tell(String task, String text) async => '';

  @override
  Future<(List<EgressHost>, List<String>, List<RemovedSetting>)> egressOf(
    String projectFile, {
    String? repository,
  }) async => (const <EgressHost>[], const <String>[], const <RemovedSetting>[]);

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
  Stream<PullRequestsSeen> watchPullRequests(String project) => const Stream<PullRequestsSeen>.empty();

  @override
  Stream<CentralPushProgress> pushToCentral(String project, {List<String>? repositories}) =>
      const Stream<CentralPushProgress>.empty();

  @override
  Future<MessagesJoined> joinMessages(String project, String person, {bool reset = false}) async =>
      throw UnimplementedError();

  @override
  Future<List<MessageMember>> messageMembers(String project) async => const <MessageMember>[];

  @override
  Future<MessageMemberRemoved> removeMessageMember(String project, String person) async =>
      throw const FeatureNotSupported('RemoveMessageMember');

  Future<MachineDeployKey> deployKey(
    String project, {
    String? repository,
    String? upstream,
    bool? readOnly,
    bool renew = false,
  }) async => throw UnimplementedError();

  @override
  Future<String> contract() async => '';

  @override
  Future<List<DefaultRepository>> defaultRepositories() async => const <DefaultRepository>[];

  @override
  Future<List<NamedDefaultRepository>> namedDefaultRepositories() async => const <NamedDefaultRepository>[];

  @override
  Future<DefaultRepository> addToDefault(String upstream, {String? name}) async => throw UnimplementedError();

  @override
  Future<({bool removed, List<MachineDeployKey> keys})> removeFromDefault(String name) async =>
      (removed: false, keys: const <MachineDeployKey>[]);

  @override
  Future<({bool removed, List<MachineDeployKey> keys})> leaveDefault(String name) async =>
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
  Future<ScreenPage> screenBefore(
    String task, {
    required String of,
    required int before,
    required int lines,
    bool escapes = false,
  }) async => throw const FeatureNotSupported('ScreenBefore');

  @override
  Future<Usage> usage(String task) async => throw const FeatureNotSupported('Usage');

  @override
  Future<ImageSettings> imageSettings(String task) async => throw const FeatureNotSupported('ImageSettings');

  @override
  Future<FirstStart> firstStart(String checkout) async => throw const FeatureNotSupported('FirstStart');

  @override
  Future<String> confirmFirstStart(String checkout, String hash) async =>
      throw const FeatureNotSupported('ConfirmFirstStart');

  @override
  Stream<LogChunk> tailLog(String task, String log, {int? last, bool formatted = false}) =>
      const Stream<LogChunk>.empty();

  @override
  Future<LogPage> logBefore(
    String task,
    String log, {
    required String of,
    required int before,
    required int lines,
    bool formatted = false,
  }) => throw UnimplementedError();
  @override
  Future<Widened> widenTask(String task, List<String> domains, {required Scope scope, bool? dryRun}) async =>
      throw UnimplementedError();

  @override
  Future<AgentsOnTheMachine> agentsOn() async =>
      (agents: const <Agent>[], failures: const <String, String>{}, shadowed: const <ShadowedAgent>[]);

  @override
  Future<OfferedModels> modelsOn(String provider, {String? agent}) async => throw const FeatureNotSupported('Models');

  @override
  Future<Panicked> panic({bool? dryRun}) async =>
      const Panicked(tasks: <PanickedTask>[], surviving: <String>[], previewed: false);

  @override
  Future<String> node() async => '';

  @override
  Future<String> limitsLine() async => '';

  @override
  Future<AccountSettings> accountSettings() async => _someSettings;

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
  Future<SettingsAllowed> allowSettings(String repository, String hash) async =>
      const SettingsAllowed(outcome: 'ALLOWED');

  @override
  Future<Deletion> removeProject(String project, {bool? dryRun, bool? force}) async => const Deletion(
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
  Future<List<AgentSignIn>> agentSignIns() async => throw const FeatureNotSupported('AgentSignIns');

  @override
  Future<SignInStarted> agentSignInStart(String agent, {bool? force, bool? remote, Future<void>? abandoned}) async =>
      throw const FeatureNotSupported('AgentSignInStart');

  @override
  Stream<SignInWaited> agentSignInWait(String agent) =>
      Stream<SignInWaited>.error(const FeatureNotSupported('AgentSignInWait'));

  @override
  Future<List<ProviderModel>> providerModels(String project, {String? repository}) async =>
      throw const FeatureNotSupported('ProviderModels');

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
  Future<TakenProject> takeProject(String project) async => const TakenProject();

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

  /// How often [watch] was asked for.
  int watches = 0;

  @override
  Stream<List<Task>> watch() {
    watches++;
    return const Stream<List<Task>>.empty();
  }

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
    bool? now,
    String? from,
  }) => const Stream<StartEvent>.empty();

  @override
  Future<Stopped> stopTask(String task) async => throw UnimplementedError();

  @override
  Future<Removed> removeTask(String task, {bool? rescue, bool? force}) async => throw UnimplementedError();

  @override
  Future<StartProgress> startDiscussion({
    required String project,
    required String agent,
    required String model,
    required Mode mode,
    required String prompt,
    required StartParts parts,
    String? callerKey,
    void Function(StartEvent event)? onEvent,
  }) => throw UnimplementedError();

  @override
  Future<TaskResult> taskResult(String task) => throw UnimplementedError();

  @override
  Future<TaskReports> taskReports(String task, {int? after}) => throw UnimplementedError();

  @override
  Future<String?> whyNoDiscussion() => throw UnimplementedError();

  @override
  Future<StartProgress> startOrdered({
    required String project,
    required String repository,
    required String agent,
    required String model,
    required Mode mode,
    required String prompt,
    required StartParts parts,
    String? callerKey,
    void Function(StartEvent event)? onEvent,
    String? result,
    Map<String, String> given = const {},
    TrackedWork? work,
    String? task,
  }) async => throw const VarlinkDisconnected('nothing there');

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
  Future<PushReview> reviewOf(
    String projectFile,
    String name, {
    String? against,
    String? repository,
    bool? ignoreLineEndings,
  }) async => const PushReview();

  @override
  Future<ReviewPage> reviewPageOf(
    String projectFile,
    String name, {
    String? repository,
    required String commit,
    required String against,
    required bool ignoreLineEndings,
    required String part,
    required int from,
  }) async => (files: null, commits: null, text: null, next: null);

  @override
  Future<ReviewSummary> reviewSummaryOf(
    String projectFile,
    String name, {
    String? repository,
    required String commit,
  }) => throw const FeatureNotSupported('ReviewSummary');

  @override
  Future<ForwardedPush> approve(
    String projectFile,
    String name,
    String branch, {
    String? repository,
    String? commit,
  }) async => ForwardedPush(forwarded: name, branch: branch);

  @override
  Future<TriedPush> credentialTryPush(
    String project, {
    String? repository,
    required String refspec,
    required String source,
    required String id,
  }) async => throw UnimplementedError();

  @override
  Future<({bool? told})> reject(String projectFile, String name, {String? repository, String? reason}) async =>
      (told: null);

  @override
  Future<PushEnd> pushEnd(String projectFile, String name, {String? repository}) async => throw UnimplementedError();

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
  Stream<PullRequestsSeen> watchPullRequests(String project) => const Stream<PullRequestsSeen>.empty();

  @override
  Stream<CentralPushProgress> pushToCentral(String project, {List<String>? repositories}) =>
      const Stream<CentralPushProgress>.empty();

  @override
  Future<MessagesJoined> joinMessages(String project, String person, {bool reset = false}) async =>
      throw UnimplementedError();

  @override
  Future<List<MessageMember>> messageMembers(String project) async => const <MessageMember>[];

  @override
  Future<MessageMemberRemoved> removeMessageMember(String project, String person) async =>
      throw const FeatureNotSupported('RemoveMessageMember');

  Future<MachineDeployKey> deployKey(
    String project, {
    String? repository,
    String? upstream,
    bool? readOnly,
    bool renew = false,
  }) async => throw UnimplementedError();

  @override
  Future<String> contract() async => '';

  @override
  Future<List<DefaultRepository>> defaultRepositories() async => const <DefaultRepository>[];

  @override
  Future<List<NamedDefaultRepository>> namedDefaultRepositories() async => const <NamedDefaultRepository>[];

  @override
  Future<DefaultRepository> addToDefault(String upstream, {String? name}) async => throw UnimplementedError();

  @override
  Future<({bool removed, List<MachineDeployKey> keys})> removeFromDefault(String name) async =>
      (removed: false, keys: const <MachineDeployKey>[]);

  @override
  Future<({bool removed, List<MachineDeployKey> keys})> leaveDefault(String name) async =>
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
  Future<(List<EgressHost>, List<String>, List<RemovedSetting>)> egressOf(
    String projectFile, {
    String? repository,
  }) async => (const <EgressHost>[], const <String>[], const <RemovedSetting>[]);

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
  Future<ScreenPage> screenBefore(
    String task, {
    required String of,
    required int before,
    required int lines,
    bool escapes = false,
  }) async => throw const FeatureNotSupported('ScreenBefore');

  @override
  Future<Usage> usage(String task) async => throw const FeatureNotSupported('Usage');

  @override
  Future<ImageSettings> imageSettings(String task) async => throw const FeatureNotSupported('ImageSettings');

  @override
  Future<FirstStart> firstStart(String checkout) async => throw const FeatureNotSupported('FirstStart');

  @override
  Future<String> confirmFirstStart(String checkout, String hash) async =>
      throw const FeatureNotSupported('ConfirmFirstStart');

  @override
  Stream<LogChunk> tailLog(String task, String log, {int? last, bool formatted = false}) =>
      const Stream<LogChunk>.empty();

  @override
  Future<LogPage> logBefore(
    String task,
    String log, {
    required String of,
    required int before,
    required int lines,
    bool formatted = false,
  }) => throw UnimplementedError();
  @override
  Future<Widened> widenTask(String task, List<String> domains, {required Scope scope, bool? dryRun}) async =>
      throw UnimplementedError();

  @override
  Future<AgentsOnTheMachine> agentsOn() async =>
      (agents: const <Agent>[], failures: const <String, String>{}, shadowed: const <ShadowedAgent>[]);

  @override
  Future<OfferedModels> modelsOn(String provider, {String? agent}) async => throw const FeatureNotSupported('Models');

  @override
  Future<Panicked> panic({bool? dryRun}) async =>
      const Panicked(tasks: <PanickedTask>[], surviving: <String>[], previewed: false);

  @override
  Future<String> node() async => '';

  /// The limits line this machine gives; null for one that does not answer the call.
  String? limits = '';

  /// What asking for the limits throws instead, where set.
  Exception? limitsFail;

  @override
  Future<String> limitsLine() async {
    if (limitsFail case final fail?) throw fail;
    return limits ?? (throw const FeatureNotSupported('Limits'));
  }

  /// The account settings this machine gives; null for one that does not answer the call.
  AccountSettings? settings = _someSettings;

  @override
  Future<AccountSettings> accountSettings() async => settings ?? (throw const FeatureNotSupported('AccountSettings'));

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
  Future<SettingsAllowed> allowSettings(String repository, String hash) async =>
      const SettingsAllowed(outcome: 'ALLOWED');

  @override
  Future<Deletion> removeProject(String project, {bool? dryRun, bool? force}) async => const Deletion(
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
  Future<List<AgentSignIn>> agentSignIns() async => throw const FeatureNotSupported('AgentSignIns');

  @override
  Future<SignInStarted> agentSignInStart(String agent, {bool? force, bool? remote, Future<void>? abandoned}) async =>
      throw const FeatureNotSupported('AgentSignInStart');

  @override
  Stream<SignInWaited> agentSignInWait(String agent) =>
      Stream<SignInWaited>.error(const FeatureNotSupported('AgentSignInWait'));

  @override
  Future<List<ProviderModel>> providerModels(String project, {String? repository}) async =>
      throw const FeatureNotSupported('ProviderModels');

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

  // Harm: what waits for a server with no project to be asked, as reading one of its pages, waits for ever: it is
  // never connected and never unreachable, so its connecting never ends.
  test('a server with no project counts as asked at once, so nothing waits for it for ever', () async {
    final fleet = FleetModel(_Machine(), noProject: true);
    addTearDown(fleet.dispose);
    await fleet.connect();
    var asked = false;
    unawaited(fleet.untilAsked().then((_) => asked = true));
    await Future<void>.delayed(Duration.zero);
    expect(asked, isTrue);
    expect(fleet.reachability, isNot(Reachability.connected), reason: 'nothing on it answers');
  });

  // Harm: a machine's factors are not the ones its waits follow, or a machine that gives none leaves the window with
  // factors another machine gave, unsaid.
  test('the factors a machine gives are kept for it on connecting, and one that gives none is said', () async {
    addTearDown(() => machineLimits.forget('slow-box'));
    final backend = _Machine()..limits = 'services=2.0,machines=2.0';
    final fleet = FleetModel(backend, machine: 'slow-box');
    addTearDown(fleet.dispose);
    await fleet.connect();

    expect(fleet.limitsProblem, isNull);
    expect(machineLimits.lineOf('slow-box'), 'services=2.0,machines=2.0');
    expect(serviceWait(const Duration(seconds: 30), machine: 'slow-box'), const Duration(seconds: 60));
    expect(machineWait(const Duration(seconds: 5), machine: 'slow-box'), const Duration(seconds: 10));
    expect(serviceWait(const Duration(seconds: 30), machine: 'another'), const Duration(seconds: 30));

    // Factors that could not be read are said as such, the ones given before stay, and the machine stays connected.
    backend.limits = 'services=fast';
    await fleet.connect();
    expect(fleet.limitsProblem, contains('cannot read'));
    expect(fleet.reachability, Reachability.connected);
    expect(serviceWait(const Duration(seconds: 30), machine: 'slow-box'), const Duration(seconds: 60));
    backend.limitsFail = const VarlinkDisconnected('Limits was not answered within 30 seconds');
    await fleet.connect();
    expect(fleet.limitsProblem, contains('did not give them'));
    expect(fleet.reachability, Reachability.connected);
    backend.limitsFail = null;

    backend.limits = null;
    await fleet.connect();
    expect(fleet.limitsProblem, contains('did not give them'));
    expect(fleet.reachability, Reachability.connected);
    expect(machineWait(const Duration(seconds: 5), machine: 'slow-box'), const Duration(seconds: 10));
    expect(machineWait(const Duration(seconds: 5), machine: 'never-read'), const Duration(seconds: 5));
  });

  // Harm: what follows a machine's factors from the start (the planner the window starts) starts on a default after a
  // connection that could not read them, or waits for ever after the machine is let go.
  test('the first factors are waited for until a connection read them, or the machine is let go', () async {
    addTearDown(() => machineLimits.forget('late-box'));
    final backend = _Machine()..limitsFail = const VarlinkDisconnected('Limits was not answered');
    final fleet = FleetModel(backend, machine: 'late-box');
    var given = false;
    unawaited(fleet.untilLimitsAsked().then((_) => given = true));
    await fleet.connect();
    await Future<void>.delayed(Duration.zero);
    expect(given, isFalse, reason: 'released by a connection that did not read the factors');

    backend.limitsFail = null;
    await fleet.connect();
    await Future<void>.delayed(Duration.zero);
    expect(given, isTrue);
    fleet.dispose();

    final never = FleetModel(_Machine()..limitsFail = const VarlinkDisconnected('no'), machine: 'late-box');
    var released = false;
    unawaited(never.untilLimitsAsked().then((_) => released = true));
    never.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(released, isTrue, reason: 'a machine let go leaves its waiters waiting');
  });

  // Harm: a machine that does not give the person's account settings runs on settings it never gave, unsaid.
  test('account settings a machine does not give are said and never replaced by a default', () async {
    addTearDown(() => machineSettings.forget('plain-box'));
    final backend = _Machine()..settings = null;
    final fleet = FleetModel(backend, machine: 'plain-box');
    addTearDown(fleet.dispose);
    await fleet.connect();

    expect(fleet.settingsProblem, contains('did not give them'));
    expect(fleet.reachability, Reachability.connected);
    expect(machineSettings.of('plain-box'), isNull);

    backend.settings = _someSettings;
    await fleet.connect();
    expect(fleet.settingsProblem, isNull);
    expect(machineSettings.of('plain-box'), _someSettings);
  });

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

  // Harm: a removed task's planning offer stays kept, or a refused removal drops the offer of a task still there.
  test('only a removal the machine confirmed is told, by the container it named', () async {
    final told = <String>[];
    final fleet = FleetModel(_Removing(removes: true), onRemoved: told.add);
    await fleet.connect();

    await fleet.removeWork('porelo-demo-st1');
    expect(told, ['porelo-demo-st1']);

    final refusing = FleetModel(_Removing(removes: false), onRemoved: told.add);
    await refusing.connect();
    await refusing.removeWork('porelo-demo-st2');
    expect(told, ['porelo-demo-st1'], reason: 'a refused removal keeps the task');
    fleet.dispose();
    refusing.dispose();
  });

  // Harm: a work tile's restart refused for a missing sign-in fails without a word, or says the wire's type name, and
  // the person does not know which agent needs signing in, or where.
  test('a restart refused for a missing sign-in says which agent on which machine', () async {
    final fleet = FleetModel(_SignInNeeded(), machine: 'build-host');
    await fleet.connect();
    final task = fleet.tasks.single;

    await fleet.startAgain(task);

    expect(fleet.status, contains('claude is not signed in on build-host'));
    expect(fleet.status, isNot(contains('SignInNeeded')));
    fleet.dispose();
  });

  // Harm: a fault on the way to the machine, a timeout among them, is said as Start's refusal and swallowed, so
  // the person reads a refusal the machine never gave.
  test('a restart that times out is no refusal: the timeout goes on as before', () async {
    final fleet = FleetModel(_SignInNeeded(fails: TimeoutException('Start')), machine: 'build-host');
    await fleet.connect();

    await expectLater(fleet.startAgain(fleet.tasks.single), throwsA(isA<TimeoutException>()));
    expect(fleet.status, isNot(contains('was not started')));
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

    // Harm: a task's orphan group must not become a project offered to project-scoped APIs.
    expect(fleet.listedProjects.map((project) => project.name), ['never-run', 'busy']);
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

  // Harm: a machine whose Porelo has no Watch is asked for one again every few seconds, for as long as the window is
  // open, and its status line repeats that it cannot push changes.
  test('a watch the machine cannot serve is not asked for again', () async {
    final backend = _WithoutWatch();
    final fleet = FleetModel(backend, retryAfter: const Duration(milliseconds: 5));
    await fleet.connect();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(backend.watches, 1);
    expect(fleet.liveUpdates, isFalse);
    fleet.dispose();
  });

  // Harm: a watch the machine ended is never opened again, and nothing it says reaches the window until a restart.
  test('a watch the machine ended is opened again after a pause', () async {
    final backend = _Machine();
    final fleet = FleetModel(backend, retryAfter: const Duration(milliseconds: 5));
    await fleet.connect();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(backend.watches, greaterThan(1));
    fleet.dispose();
  });
  // Harm: a watch the machine refused with an error is asked for again every few seconds, the refusal said each time.
  test('a watch that failed with an error and then ended is not asked for again', () async {
    final backend = _WatchFails(const VarlinkException('org.fuin.porelo.Tasks1.Refused'));
    final fleet = FleetModel(backend, retryAfter: const Duration(milliseconds: 5));
    await fleet.connect();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(backend.watches, 1);
    fleet.dispose();
  });

  // Harm: a window closed while a watch waited to be opened again keeps asking its machine for one.
  test('a watch waiting to be opened again is not opened once the machine is let go', () async {
    final backend = _Machine();
    final fleet = FleetModel(backend, retryAfter: const Duration(milliseconds: 40));
    await fleet.connect();
    // The first watch has ended, and its reopening waits.
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final before = backend.watches;
    fleet.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(backend.watches, before);
  });

  // Harm: a watch opened again that sends nothing at first leaves the projects as they were read before it ended.
  test('a watch opened again reads the projects anew', () async {
    final backend = _ProjectsCounted();
    final fleet = FleetModel(backend, retryAfter: const Duration(milliseconds: 20));
    await fleet.connect();
    final before = backend.projectsRead;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(backend.projectsRead, greaterThan(before));
    fleet.dispose();
  });
}

/// A machine whose one project lists one task, and whose Start refuses it because its agent is not signed in.
class _SignInNeeded extends _Machine {
  _SignInNeeded({this.fails});

  /// What Start fails with in place of its refusal, where set.
  final Object? fails;

  @override
  Future<List<Project>> projects() async => <Project>[
    Project.from(const <String, dynamic>{'name': 'demo', 'file': '/srv/demo/project.yml', 'tasks': 1}),
  ];

  @override
  Future<List<Task>> tasks() async => <Task>[
    Task.from(const <String, dynamic>{'name': 'porelo-demo-fix', 'task': 'fix', 'project': 'demo'}),
  ];

  @override
  Future<StartProgress> startAgain({required String project, required String task, String? repository}) async =>
      throw fails ??
          startRefusalSaid(
            const VarlinkException('org.fuin.porelo.Tasks1.SignInNeeded', <String, dynamic>{'agent': 'claude'}),
          );
}

/// A machine whose watch fails with [error] and then ends.
class _WatchFails extends _Machine {
  _WatchFails(this.error);

  final Object error;

  @override
  Stream<List<Task>> watch() {
    watches++;
    return Stream<List<Task>>.error(error);
  }
}

/// A machine whose watch ends at once and whose project list is counted.
class _ProjectsCounted extends _Machine {
  int projectsRead = 0;

  @override
  Future<List<Project>> projects() {
    projectsRead++;
    return super.projects();
  }
}

/// A machine whose Porelo is older than `Watch`.
class _WithoutWatch extends _Machine {
  @override
  Stream<List<Task>> watch() {
    watches++;
    return Stream<List<Task>>.error(const FeatureNotSupported('Watch'));
  }
}

/// A machine whose removals are confirmed, or refused as holding work.
class _Removing extends _Machine {
  _Removing({required this.removes});

  final bool removes;

  @override
  Future<Removed> removeTask(String task, {bool? rescue, bool? force}) async =>
      Removed.from(<String, dynamic>{'outcome': removes ? 'REMOVED' : 'HOLDS_WORK', 'removed': removes});
}

/// Account settings a stand-in machine gives.
const _someSettings = AccountSettings(
  certificateDays: 7,
  cardDays: 30,
  renewNoticeDays: 7,
  askedAboutDays: 7,
  keptDays: 30,
);
