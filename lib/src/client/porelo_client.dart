import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../wire/varlink_connection.dart';
import '../wire/varlink_exception.dart';
import 'models.dart';
import 'environment.dart';

/// A relay ended before the daemon answered, retaining the transport's own verdict.
class RelayDisconnected extends VarlinkDisconnected {
  /// Constructor taking the bounded diagnostic and exit status, if it arrived in time.
  const RelayDisconnected(super.message, this.exitCode);

  /// The relay's exit status, or null when it did not exit within the diagnostic deadline.
  final int? exitCode;
}

/// Where a backend is.
///
/// Local and remote differ by one string - the socket path - because a remote daemon is reached
/// by forwarding its socket over SSH. **There is no second protocol, and there must never be
/// one**: where no socket can be opened, as from Windows into a WSL distribution, the same Varlink
/// runs over the standard input and output of [relay], `porelo daemon connect` on the far side,
/// which joins them to the daemon's socket.
class Backend {
  /// Path to the daemon's unix socket.
  final String socketPath;

  /// What to call this backend in the interface. Several may be reachable at once, and an action
  /// must never be ambiguous about which machine it acts on.
  final String label;

  /// Why this backend cannot be reached from here, or null. When set, nothing is opened: every
  /// call ends at once as a lost connection with these words.
  final String? notReachable;

  /// The program, and its arguments, whose standard input and output are the daemon, or null for a
  /// socket. Started as a process of its own for each connection, never through a shell.
  final List<String>? relay;

  /// Asked before each connection through [relay]: why not now, or null. A relay can start what it
  /// reaches, and this is where a WSL distribution that is stopped stays stopped.
  final Future<String?> Function()? whyNotNow;

  /// Constructor with the socket and how to name it.
  const Backend({required this.socketPath, required this.label, this.notReachable, this.relay, this.whyNotNow});

  /// Opens a connection to it, or says in [notReachable]'s words why there is none.
  Future<VarlinkConnection> open() async {
    final why = notReachable;
    if (why != null) throw VarlinkDisconnected(why);
    final through = relay;
    if (through == null) return VarlinkConnection.open(socketPath);
    final notNow = await whyNotNow?.call();
    if (notNow != null) throw VarlinkDisconnected(notNow);
    final Process process;
    try {
      process = await Process.start(through.first, through.sublist(1));
    } on ProcessException catch (failed) {
      throw VarlinkDisconnected('`${through.first}` could not be started: ${failed.message}');
    }
    final lastBytes = <int>[];
    // Bound diagnostics even when a relay prints endlessly without a newline.
    final diagnostics = process.stderr.forEach((bytes) {
      lastBytes.addAll(bytes);
      if (lastBytes.length > 8192) lastBytes.removeRange(0, lastBytes.length - 8192);
    });
    Future<RelayDisconnected>? ending;
    Future<RelayDisconnected> ended() => ending ??= () async {
      final status = process.exitCode.timeout(const Duration(seconds: 1), onTimeout: () => -1);
      await diagnostics.timeout(const Duration(seconds: 1), onTimeout: () {});
      final code = await status;
      final words = utf8.decode(lastBytes, allowMalformed: true).trim();
      return RelayDisconnected(words.isEmpty ? 'The relay closed the connection.' : words, code == -1 ? null : code);
    }();
    Stream<List<int>> incoming() async* {
      yield* process.stdout;
      throw await ended();
    }

    return VarlinkConnection.over(
      incoming: incoming(),
      outgoing: process.stdin,
      destroy: process.kill,
      writeFailure: ended,
    );
  }

  /// The daemon on this machine.
  factory Backend.local() => Backend(socketPath: _localSocket, label: 'this machine');

  /// Worked out once: it is compared against every machine, and asking `id` each time ran a
  /// process on the interface's own thread.
  ///
  /// On Windows there is no local daemon: Porelo runs in a WSL distribution, a machine of its own, and
  /// `id` is not asked there.
  static final String _localSocket = Platform.isWindows
      ? ''
      : '${setIn('XDG_RUNTIME_DIR') ?? '/run/user/${_uid()}'}/porelo/porelod.sock';

  static String _uid() => Process.runSync('id', const ['-u']).stdout.toString().trim();
}

/// A feature this build has that the backend it is talking to does not.
///
/// Thrown instead of a raw error so a caller cannot mistake it for a failure: the interface
/// disables that one feature and keeps everything else. A backend is routinely older than the
/// interface pointed at it, and refusing to connect over one missing method would make a fleet
/// unusable during any upgrade.
class FeatureNotSupported implements Exception {
  /// The method the backend does not have.
  final String method;

  /// Constructor with the missing method.
  const FeatureNotSupported(this.method);

  @override
  String toString() => 'this backend has no $method';
}

/// What one machine has to run agents with: the ones it can use, the ones it cannot, and the ones
/// it will never reach.
///
/// Named rather than positional, because three lists of different things in a row is three
/// positions somebody has to remember at every call site.
typedef AgentsOnTheMachine = ({List<Agent> agents, Map<String, String> failures, List<ShadowedAgent> shadowed});

/// The Porelo backend, typed.
///
/// One [Backend] per instance. Every call opens its own connection, because the framing has no
/// request ids and a connection therefore carries one call at a time - which costs nothing and
/// means a stream can be canceled without disturbing anything else.
class PoreloClient {
  /// Interface versions this build understands, newest first.
  ///
  /// The trailing number is the compatibility promise. A backend serving a newer one also serves
  /// this one for at least a release, so taking the newest *understood* name - rather than the
  /// newest offered, and never a version comparison - is what keeps an old interface working
  /// against a new backend and the other way round.
  static const supported = <String>['org.fuin.porelo.Tasks1'];

  /// Where this is pointed.
  final Backend backend;

  /// Which interface was agreed with this backend.
  final String interfaceName;

  /// What the backend says it is.
  final ServiceInfo info;

  /// How long a single call may go unanswered. Never applied to a stream.
  final Duration answerWithin;

  PoreloClient._(this.backend, this.interfaceName, this.info, this.answerWithin);

  /// Connects and agrees an interface.
  ///
  /// Throws [VarlinkDisconnected] when there is nothing there, and [StateError] when the backend
  /// serves no interface this build knows - which is a backend too new or too old to talk to at
  /// all, and is worth saying plainly rather than failing on the first call.
  static Future<PoreloClient> connect(Backend backend, {Duration answerWithin = VarlinkConnection.answerWithin}) async {
    final connection = await backend.open();
    try {
      // Shorter than the default: "is there a daemon on the other end of this socket" has to
      // answer quickly, or the window sits on an empty frame saying it is connecting.
      final info = ServiceInfo.from(
        await connection.call('org.varlink.service.GetInfo', const {}, const Duration(seconds: 5)),
      );
      final agreed = supported.where(info.interfaces.contains);
      if (agreed.isEmpty) {
        throw StateError(
          '${backend.label} serves ${info.interfaces}, none of which this build understands '
          '(it knows $supported)',
        );
      }
      return PoreloClient._(backend, agreed.first, info, answerWithin);
    } finally {
      await connection.close();
    }
  }

  /// The contract, read off this running backend.
  ///
  /// Served by the daemon itself, so it always matches what is answering - unlike a copy.
  Future<String> contract() async {
    final reply = await _call('org.varlink.service.GetInterfaceDescription', {'interface': interfaceName}, false);
    final description = reply['description'];
    return description is String ? description : '';
  }

  Future<bool>? _startSteps;

  Future<bool> _declaresStartSteps() async {
    final String description;
    try {
      description = await contract();
    } on FeatureNotSupported {
      return false;
    } on VarlinkException catch (error) {
      if (error.name == 'org.varlink.service.InterfaceNotFound') return false;
      rethrow;
    }
    final idl = description.replaceAll(RegExp(r'#[^\n]*'), '');
    final start = RegExp(r'\bmethod\s+Start\s*\(').firstMatch(idl);
    if (start == null) return false;
    var depth = 1;
    final inputs = StringBuffer();
    for (var at = start.end; at < idl.length; at++) {
      final character = idl[at];
      if (character == '(') depth++;
      if (character == ')') depth--;
      if (depth == 0) return RegExp(r'(?:^|,)\s*steps\s*:').hasMatch(inputs.toString());
      if (depth == 1) inputs.write(character);
    }
    return false;
  }

  // --------------------------------------------------------------------- what exists

  /// Every task on the machine, running or stopped.
  Future<List<Task>> tasks() async => _tasksOf(await _call('List'));

  /// The task list, again whenever it changes.
  ///
  /// Only on change, and the age in [Task.state] does not count as one - it moves on its own, and
  /// a view redrawing for it would redraw every second forever.
  Stream<List<Task>> watchTasks() => _callMore('Watch').map(_tasksOf);

  /// Agent binaries installed on the machine.
  ///
  /// The second value is what could not be asked, by file name. An agent that fails to describe
  /// itself is installed and unusable, and leaving it out would read as absent.
  Future<AgentsOnTheMachine> agents() async {
    final reply = await _call('Agents');
    final found = reply['agents'];
    final failures = reply['failures'];
    final shadowed = reply['shadowed'];
    return (
      // One entry per name: they are keyed by name on the daemon side, and a copy that loses to
      // another is resolved away before this list is built rather than marked in it.
      agents: found is List ? found.whereType<Map<String, dynamic>>().map(Agent.from).toList() : <Agent>[],
      failures: failures is Map ? failures.map((key, value) => MapEntry('$key', '$value')) : <String, String>{},
      shadowed: shadowed is List
          ? shadowed.whereType<Map<String, dynamic>>().map(ShadowedAgent.from).toList()
          : <ShadowedAgent>[],
    );
  }

  /// What the vault holds, without any of it.
  Future<VaultState> credentials() async => VaultState.from(await _call('Credentials'));

  /// Records a credential this machine may use. **No secret crosses this socket**: the answer says
  /// what to run on the machine to store the value.
  Future<CredentialDeclared> credentialDeclare({
    required String kind,
    required String match,
    String? id,
    String? user,
    String? purpose,
    String? source,
    String? fromFile,
    bool? dryRun,
  }) async => CredentialDeclared.from(
    await _call('CredentialDeclare', {
      'id': ?id,
      'kind': kind,
      'match': match,
      'user': ?user,
      'purpose': ?purpose,
      'source': ?source,
      'fromFile': ?fromFile,
      'dryRun': ?dryRun,
    }),
  );

  /// Forgets a credential record. The secret stays where it is; the answer says what still holds it.
  Future<CredentialForgotten> credentialForget(String match) async =>
      CredentialForgotten.from(await _call('CredentialForget', {'match': match}));

  /// Which credential [url] would use, and whether it would work, without touching the network.
  Future<CredentialChecked> credentialCheck(String url, {String? purpose}) async =>
      CredentialChecked.from(await _call('CredentialCheck', {'url': url, 'purpose': ?purpose}));

  /// Records the one key of [host] a person confirmed, and only if the host still offers it.
  Future<HostKeyTrusted> trustHostKey(String host, String fingerprint) async =>
      HostKeyTrusted.from(await _call('TrustHostKey', <String, dynamic>{'host': host, 'fingerprint': fingerprint}));

  /// The ssh keys the account already has on the machine, never with a value.
  Future<List<SshKey>> sshKeys() async {
    final keys = (await _call('SshKeys', const <String, dynamic>{}))['keys'];
    return keys is List ? keys.whereType<Map<String, dynamic>>().map(SshKey.from).toList() : const <SshKey>[];
  }

  // --------------------------------------------------------------------- the registry

  /// Core's verdict on the registry checkout at [checkout], a folder on this daemon's own machine.
  ///
  /// Throws a [FormatException] when the answer is incomplete, never an empty registry. The method's name
  /// and its parameter are assumed until Core serves them.
  Future<RegistryRead> registryRead(String checkout) async =>
      RegistryRead.from(await _call('RegistryRead', <String, dynamic>{'checkout': checkout}));

  /// Has Core write and sign one registry change in [checkout] with the person's key, by plain Git.
  ///
  /// [kind] is `card`, `host-card` or `host-access`; [host] names the host a host change is for and
  /// [person] the login an access change names. Nothing is pushed: publishing is the caller's. The
  /// method's name and its parameters are assumed until Core serves them.
  Future<RegistryFiled> registryFile(String checkout, {required String kind, String? host, String? person}) async =>
      RegistryFiled.from(
        await _call('RegistryFile', <String, dynamic>{
          'checkout': checkout,
          'kind': kind,
          'host': ?host,
          'person': ?person,
        }),
      );

  // --------------------------------------------------------------------- running tasks

  /// Starts a task, streaming the build as it happens.
  ///
  /// The task outlives this call: canceling the stream stops the reporting, never the launch.
  /// Building an image takes minutes, so an interface must show these lines rather than nothing.
  ///
  /// **Giving a [prompt] makes this call run the agent**, not merely bring the container up. It
  /// then lasts as long as the run — minutes, sometimes tens of them — which is why `Start`
  /// streams and why nothing here puts a deadline on it. A deadline would not stop the agent
  /// anyway: the run carries on in the container and the caller has only stopped watching, which
  /// is a different thing to tell somebody than "canceled".
  ///
  /// What arrives is the **raw log**, the same text `Tail` serves for `task.log`. The formatted
  /// view an agent can produce is made in the CLI process and is not on the wire.
  ///
  /// [mode] is genuinely optional and **the backend's default depends on the prompt** —
  /// `UNATTENDED` when one is given, `SHELL` otherwise — so nothing is restated here. What must
  /// never be sent is `SHELL` together with a prompt: it is accepted and recorded, and it says a
  /// person is driving a run nobody is attached to.
  ///
  /// Without a prompt nothing changed: the container comes up and the call returns.
  Stream<StartProgress> start({
    String? task,
    String? project,
    String? agent,
    String? provider,
    String? credentialType,
    int? tokenHours,
    String? upstream,
    bool? noGate,
    bool? dryRun,
    String? clearance,
    bool? rm,
    bool? now,
    Mode? mode,
    String? prompt,
    String? model,
    int? maxTurns,
    int? minutes,
    String? repository,
    Map<String, String>? credentials,
  }) async* {
    // Only what the caller named is sent, so the backend's own defaults stay the only defaults.
    // Restating them here would be a second place for them to drift.
    final parameters = <String, dynamic>{
      'task': ?task,
      'project': ?project,
      'agent': ?agent,
      'provider': ?provider,
      'credentialType': ?credentialType,
      'tokenHours': ?tokenHours,
      'upstream': ?upstream,
      'noGate': ?noGate,
      'dryRun': ?dryRun,
      'clearance': ?clearance,
      'rm': ?rm,
      // Answers once the task exists, without waiting for its image to be built.
      'now': ?now,
      'mode': ?mode?.name,
      'prompt': ?prompt,
      'model': ?model,
      'maxTurns': ?maxTurns,
      'minutes': ?minutes,
      // A vault entry's name to the destination or provider it is for, beyond the project's own.
      if (credentials != null && credentials.isNotEmpty) 'credentials': credentials,
      // Required by a Porelo with repositories per project, with no default; sent only when named, so an older one never
      // meets a parameter it does not know.
      'repository': ?repository,
      if (await (_startSteps ??= _declaresStartSteps())) 'steps': true,
    };
    yield* _callMore('Start', parameters).map(StartProgress.from);
  }

  /// Stops a task, keeping it: its container is its workspace. Removing is [remove].
  Future<Stopped> stop(String task) async => Stopped.from(await _call('Stop', {'task': task}));

  /// Removes a task, or refuses rather than destroys.
  ///
  /// A task holding commits that never reached the gate comes back as [Outcome.holdsWork],
  /// untouched. That refusal needs a real place in the interface - it is the product working.
  Future<Removed> remove(String task, {bool? rescue, bool? force}) async =>
      Removed.from(await _call('Remove', {'task': task, 'rescue': ?rescue, 'force': ?force}));

  /// Every project on the machine.
  ///
  /// Nothing refreshes this: `WatchProjects` is not used yet, so it is asked again after anything
  /// that would change it — a task started or removed, a push approved.
  Future<List<Project>> projects() async {
    final reply = await _call('Projects');
    final projects = reply['projects'];
    return projects is List ? projects.whereType<Map<String, dynamic>>().map(Project.from).toList() : const <Project>[];
  }

  /// The curated destination sets installed on this machine, and where they were found.
  ///
  /// Scanned every time rather than fixed: a set an operator drops into their own directory turns
  /// up without anything being rebuilt, and theirs wins over a packaged one of the same name —
  /// which is why the locations come back in search order.
  Future<(List<EgressSet>, List<String>)> sets() async {
    final reply = await _call('Sets');
    final sets = reply['sets'];
    final locations = reply['locations'];
    return (
      sets is List ? sets.whereType<Map<String, dynamic>>().map(EgressSet.from).toList() : <EgressSet>[],
      locations is List ? locations.whereType<String>().toList() : <String>[],
    );
  }

  /// What a project's work may reach, and what it asks for and is deliberately not given.
  ///
  /// The whole composition a task run uses, the agent's own grants and its provider's host
  /// included. `refused` is the distinction a dropped packet cannot make: "we said no" and
  /// "nobody added it" look identical to the firewall.
  ///
  /// Without [repository] it is what every repository of the project may reach; with one, that and
  /// what the repository adds, each host naming where it came from.
  Future<(List<EgressHost>, List<String>)> egress(String project, {String? agent, String? repository}) async {
    final reply = await _call('Egress', {'project': project, 'agent': ?agent, 'repository': ?repository});
    final hosts = reply['hosts'];
    final refused = reply['refused'];
    return (
      hosts is List ? hosts.whereType<Map<String, dynamic>>().map(EgressHost.from).toList() : <EgressHost>[],
      refused is List ? refused.whereType<String>().toList() : <String>[],
    );
  }

  /// Changes what a project's work may reach, or says what the change would do.
  ///
  /// With [dryRun] it answers `PREVIEWED` and writes nothing, having worked out exactly the
  /// `opens` and `closes` a real call would produce. **Nothing here reaches a running task**: a
  /// container's ruleset is built when it starts, so a change applies to the next one.
  Future<EgressChange> setEgress(
    String project, {
    List<String>? addSets,
    List<String>? removeSets,
    List<String>? addDomains,
    List<String>? removeDomains,
    bool? dryRun,
    String? repository,
  }) async => EgressChange.from(
    await _call('SetEgress', {
      'project': project,
      'repository': ?repository,
      'addSets': ?addSets,
      'removeSets': ?removeSets,
      'addDomains': ?addDomains,
      'removeDomains': ?removeDomains,
      'dryRun': ?dryRun,
    }),
  );

  /// Lets a **running** task reach names it could not reach before.
  ///
  /// Unlike [setEgress], which edits a file the *next* task reads, this reaches the container in
  /// front of somebody: the resolver is told without being restarted, and the grant is recorded
  /// where the clearance watcher reads it.
  ///
  /// [scope] is required and there is no default — the daemon answers `ScopeRequired` to a call
  /// without one. [Scope.run] does not survive the task being stopped and started again.
  ///
  /// Names only. Sets are not granted this way, and **nothing narrows a running task**: taking a
  /// grant back from a container that has it is not decided, so there is no method for it.
  ///
  /// With [dryRun] it answers `PREVIEWED` with exactly the names a real call would grant, having
  /// changed nothing. Worth doing every time: this edit lands on work that is running.
  Future<Widened> widenTask(String task, List<String> domains, {required Scope scope, bool? dryRun}) async =>
      Widened.from(
        await _call('WidenTask', {'task': task, 'domains': domains, 'scope': scope.wire, 'dryRun': ?dryRun}),
      );

  /// Sets or clears the caption a task reads by.
  ///
  /// **Beside the identity, never instead of it.** The container name, the gate ref, the
  /// workspace and the log files do not move: renaming would move a ref that may have unreviewed
  /// pushes behind it, which is what was asked for and not what anybody wanted.
  ///
  /// An empty [label] clears it rather than storing spaces.
  Future<Labelled> label(String task, {String? label}) async =>
      Labelled.from(await _call('Label', {'task': task, 'label': ?label}));

  /// Sends one part of a file handed to a running [task]: [part] starts at [offset] of a file of
  /// [bytes] with [sha256]. Each part is a call of its own, so a cut connection loses one part, and
  /// the machine's `PartOutOfOrder` says where to go on.
  Future<HandInPart> handIn(
    String task, {
    required String name,
    required int bytes,
    required String sha256,
    required int offset,
    required List<int> part,
  }) async => HandInPart.from(
    await _call('HandIn', <String, dynamic>{
      'task': task,
      'name': name,
      'bytes': bytes,
      'sha256': sha256,
      'offset': offset,
      'part': base64.encode(part),
    }),
  );

  /// Takes the file [name] out of a running [task] again.
  Future<HandedFile> takeBack(String task, String name) async {
    final reply = await _call('TakeBack', {'task': task, 'name': name});
    return HandedFile.from(reply['file'] is Map<String, dynamic> ? reply['file'] as Map<String, dynamic> : const {});
  }

  /// Every hand-in, replacement and removal under [task]'s name, oldest first, of every run that
  /// carried it - also after the task is gone.
  Future<List<HandInEvent>> handIns(String task) async {
    final record = (await _call('HandIns', {'task': task}))['record'];
    return record is List
        ? record.whereType<Map<String, dynamic>>().map(HandInEvent.from).toList()
        : const <HandInEvent>[];
  }

  /// Shuts the vault.
  ///
  /// **There is deliberately no passphrase `Unlock`.** A daemon has no terminal to take a passphrase
  /// at, so it can shut the vault and never open it with one. A device that enrolled a keyslot opens
  /// it with a share instead — [unlockWithShare] — and the passphrase stays the recovery path at the
  /// machine.
  Future<Locked> lock() async => Locked.from(await _call('Lock'));

  /// Enrolls this device as a keyslot, sending its [share] once.
  ///
  /// **Proposed for Porelo's keyslots, not on `Tasks1` yet**: until it is built, this answers
  /// [FeatureNotSupported]. The share is base64 of 32 random bytes, is sent here and in
  /// [unlockWithShare] only, and appears in no reply.
  Future<Enrolled> enrollDevice({required String name, required String share, required KeyslotStorage storage}) async =>
      Enrolled.from(await _call('EnrollDevice', {'name': name, 'share': share, 'storage': storage.name}));

  /// Every credential that can open the vault. **Proposed for Porelo's keyslots.**
  Future<List<Keyslot>> keyslots() async {
    final reply = await _call('Keyslots');
    final slots = reply['slots'];
    return slots is List ? slots.whereType<Map<String, dynamic>>().map(Keyslot.from).toList() : const <Keyslot>[];
  }

  /// Revokes one keyslot by [id]. **Proposed for Porelo's keyslots.**
  Future<Revoked> revokeKeyslot(String id) async => Revoked.from(await _call('RevokeKeyslot', {'id': id}));

  /// Opens the vault with this device's [share], for [minutes] or the node's own bound.
  ///
  /// **As Porelo built it**: the share and an optional bound, and no keyslot id —
  /// the node finds the slot the share opens, so a device that lost its id still opens the vault.
  Future<UnlockedWithShare> unlockWithShare({required String share, int? minutes}) async =>
      UnlockedWithShare.from(await _call('UnlockWithShare', {'share': share, 'minutes': ?minutes}));

  /// Whether work can start, asked **before anything is created**.
  ///
  /// The rule turns on four things — the agent's declaration, the installed providers, the run's
  /// own override, and what the vault already holds — and a client has one of them. So this is
  /// asked rather than assembled, and `credential` names **the key that was actually looked
  /// for**: a vault written before the provider-keyed change answers under the agent's own name,
  /// and naming the other would report a key missing from a vault that has it.
  Future<Readiness> canStart({
    String? project,
    String? agent,
    String? task,
    String? provider,
    String? credentialType,
    String? repository,
    Map<String, String>? credentials,
  }) async => Readiness.from(
    await _call('CanStart', {
      'project': ?project,
      'agent': ?agent,
      'task': ?task,
      'provider': ?provider,
      'credentialType': ?credentialType,
      'repository': ?repository,
      // Sent only when there are some, so a machine older than them never meets the parameter.
      if (credentials != null && credentials.isNotEmpty) 'credentials': credentials,
    }),
  );

  /// Stops every running task and its helpers at once.
  ///
  /// **It stops and never removes.** Workspaces, logs and unpushed commits all survive, and
  /// `Start` brings a task back with the work it had — so nothing here is a cleanup, and saying
  /// otherwise would send somebody looking for work that is exactly where they left it.
  ///
  /// With [dryRun] it lists what it would stop and stops nothing. Worth doing every time: this is
  /// the action somebody reaches for without yet knowing what is wrong.
  Future<Panicked> panic({bool? dryRun}) async => Panicked.from(await _call('Panic', {'dryRun': ?dryRun}));

  /// Turns enforcement on or off on a task that is already running.
  ///
  /// **Deliberately not widening with a special value.** Those grant and withdraw names, and that
  /// the firewall stays loaded is what they mean; folding *"stop asking about anything"* into them
  /// would make one method mean two unrelated things, and the quiet one would be the dangerous
  /// one.
  Future<ClearanceSet> setClearance(String task, String mode, {bool? dryRun}) async =>
      ClearanceSet.from(await _call('SetClearance', {'task': task, 'mode': mode, 'dryRun': ?dryRun}));

  /// Takes names back from a running task, and optionally from its project file.
  ///
  /// **This stops new connections and not the ones already running.** A transfer in progress runs
  /// to its end, because the ruleset accepts established traffic without consulting the set again.
  ///
  /// [scope] is required and has no default, exactly as for widening: narrowing only the run when
  /// somebody meant the project too leaves the next task starting with the host still open.
  Future<Narrowed> narrowTask(String task, List<String> domains, {required Scope scope, bool? dryRun}) async =>
      Narrowed.from(
        await _call('NarrowTask', {'task': task, 'domains': domains, 'scope': scope.wire, 'dryRun': ?dryRun}),
      );

  /// What backups have been taken of a project's mirror.
  ///
  /// **Read from a record written when each was taken**, because a bundle is written wherever an
  /// operator names it and nothing could work that out afterwards. Newest first, and **empty is an
  /// ordinary answer**: a project nobody has backed up, or one backed up by a Porelo older than the
  /// record. It never means no bundle exists.
  ///
  /// [repository] names one of the project's repositories; without one, the project's own.
  Future<List<Backup>> backups(String project, {String? repository}) async {
    final reply = await _call('Backups', {'project': project, 'repository': ?repository});
    final backups = reply['backups'];
    return backups is List ? backups.whereType<Map<String, dynamic>>().map(Backup.from).toList() : const <Backup>[];
  }

  /// What a task holds that never reached the gate.
  ///
  /// **Asked for one task, on demand** — never while drawing a list. A name that is no task at all
  /// raises `NoSuchTask` rather than answering unreadable: those are different failures, and
  /// collapsing them would make a client's wrong argument arrive as a legitimate answer.
  Future<HeldWork> workHeld(String task) async => HeldWork.from(await _call('WorkHeld', {'task': task}));

  /// Asks the upstream how far behind a project's mirror is, now.
  Future<Synced> syncUpstream(String project, {String? repository}) async =>
      Synced.from(await _call('SyncUpstream', {'project': project, 'repository': ?repository}));

  /// Restores a mirror from a backup, or says what restoring would take.
  ///
  /// **Refuses with `HOLDS_WORK` and names the refs.** Unreviewed pushes exist only in the mirror,
  /// so overwriting one destroys the only copy there has ever been.
  ///
  /// **[repository] is the one written into**, and a bundle is kept under the repository it was
  /// taken of — restoring one into another would put one history over the other's.
  Future<Restored> restoreBackup(
    String project,
    String bundle, {
    bool? dryRun,
    bool? force,
    String? repository,
  }) async => Restored.from(
    await _call('RestoreBackup', {
      'project': project,
      'bundle': bundle,
      'repository': ?repository,
      'dryRun': ?dryRun,
      'force': ?force,
    }),
  );

  /// Removes a backup, or says what removing it would take.
  ///
  /// **It takes the path rather than an index**: a list that shifted between somebody reading it
  /// and acting on it would otherwise delete a different backup than the one they chose. And it
  /// refuses a path no record names, which is what keeps it from being a file-deletion primitive
  /// wearing a backup's name.
  Future<BackupDeleted> deleteBackup(String project, String bundle, {bool? dryRun}) async =>
      BackupDeleted.from(await _call('DeleteBackup', {'project': project, 'bundle': bundle, 'dryRun': ?dryRun}));

  /// Builds a project's task image without starting anything.
  ///
  /// **Streamed, because a build takes minutes** and showing nothing for that long is
  /// indistinguishable from having hung.
  ///
  /// [rebuild] is `CACHED`, `AGENT` or `EVERYTHING`. `CACHED` is not *"skip the build"*: the build
  /// runs and the layer cache decides line by line, which is what every task start already does.
  /// `AGENT` keeps the base image and its packages, and is a mechanism rather than a switch —
  /// there is no *"rebuild from here"*, so it works by changing a build argument placed where the
  /// agent's layers begin.
  Stream<PrepareProgress> prepare(String project, {String? agent, String? rebuild, bool? dryRun}) => _callMore(
    'Prepare',
    {'project': project, 'agent': ?agent, 'rebuild': ?rebuild, 'dryRun': ?dryRun},
  ).map(PrepareProgress.from);

  /// Whether this machine can actually run a task, and what it is short of.
  ///
  /// **It runs external programs to find out, so it takes a moment and is not something to
  /// poll.** Still a read: nothing about it changes anything.
  Future<Health> doctor() async => Health.from(await _call('Doctor', const <String, dynamic>{}));

  /// Which providers this machine has, and where a credential for each belongs.
  Future<Providers> providers() async => Providers.from(await _call('Providers', const <String, dynamic>{}));

  /// Imports a credential an agent already holds on the machine.
  ///
  /// **No secret crosses this socket doing it**: the daemon reads the agent's own config file on
  /// its own disk, and only a name comes back. [agent] omitted means *the only one installed* —
  /// which is not the same as an empty string, and an empty string matches nothing.
  Future<Imported> importCredential({String? agent, String? configDirectory}) async =>
      Imported.from(await _call('ImportCredential', {'agent': ?agent, 'configDirectory': ?configDirectory}));

  /// Which node this is.
  ///
  /// **`GetInfo` says what a daemon is and never which one.** This says which one — so two entries
  /// in a list of machines can be told to be the same node reached two ways, which a client
  /// cannot work out for itself: a hostname has many spellings, and a socket somebody else
  /// forwarded looks nothing like a tunnel this interface raised to the same place.
  ///
  /// **An empty answer is not an identity.** A daemon older than the method answers nothing, and
  /// treating that as a value would report every such machine as the same node.
  Future<String> node() async {
    final answered = await _call('Node', const <String, dynamic>{});
    final id = answered['id'];
    return id is String ? id : '';
  }

  /// Which project repositories this account follows, and how far each has got.
  Future<List<Followed>> following() async {
    final reply = await _call('Following', const <String, dynamic>{});
    final projects = reply['projects'];
    return projects is List
        ? projects.whereType<Map<String, dynamic>>().map(Followed.from).toList()
        : const <Followed>[];
  }

  /// Brings [task]'s repository at the gate up to its source and tells its agent what moved.
  Future<TaskRefreshed> refreshTask(String task) async =>
      TaskRefreshed.from(await _call('RefreshTask', {'task': task}));

  /// Fetches a followed project's repository now, or every one's when [project] is null, rather than at
  /// the machine's next round, and answers their records as they are afterwards.
  ///
  /// A fetch that failed is a record with its outcome, never an error; a named project this account
  /// does not follow raises `NoSuchProject`.
  Future<List<Followed>> refreshProjects({String? project}) async {
    final reply = await _call('RefreshProjects', {'project': ?project});
    final projects = reply['projects'];
    return projects is List
        ? projects.whereType<Map<String, dynamic>>().map(Followed.from).toList()
        : const <Followed>[];
  }

  /// Starts following a project's repository, and reconciles once, now — so a project that comes
  /// back as taken can have work started in it at once.
  ///
  /// [signedBy] is the public key its commits must be signed with; [unverified] follows without
  /// one. Porelo refuses both together: they are two instructions, not a stricter setting.
  /// [acceptRewrite] is **only ever** a person's answer to `REWRITTEN`, never a retry.
  Future<Followed> follow(
    String name,
    String url, {
    String? signedBy,
    List<String>? signers,
    bool? unverified,
    bool? acceptRewrite,
    bool? dryRun,
  }) async => Followed.from(<String, dynamic>{
    'name': name,
    'url': url,
    ...await _call('Follow', {
      'name': name,
      'url': url,
      'signedBy': ?signedBy,
      'signers': ?signers,
      'unverified': ?unverified,
      'acceptRewrite': ?acceptRewrite,
      'dryRun': ?dryRun,
    }),
  });

  /// Clears this machine of a project, or of every project with none named: its tasks, workspaces,
  /// gate, mirrors, follow and conversation, leaving what only a person's credentials remove named.
  Future<Cleared> clear({String? project, bool? dryRun, bool? force}) async =>
      Cleared.from(await _call('Clear', {'project': ?project, 'dryRun': ?dryRun, 'force': ?force}));

  /// Stops following a project, and removes it and everything Porelo built for it from this machine.
  ///
  /// It **refuses rather than decides**: unreviewed pushes exist only in the mirror and a running
  /// task is work cut off mid-flight. [force] is how somebody says they meant it. The project's own
  /// repository is not on this machine and is never touched.
  Future<Deletion> unfollow(String name, {bool? dryRun, bool? force}) async =>
      Deletion.from(await _call('Unfollow', {'name': name, 'dryRun': ?dryRun, 'force': ?force}));

  /// Which logs a task has.
  ///
  /// Asked rather than assumed: which files exist depends on what the task started — one with no
  /// gate has no `gate.log`, one run with clearance off has no `clearance.log` — so a client that
  /// held the names would open an empty viewer on a file that was never going to exist, and would
  /// never show one a later release adds.
  ///
  /// **Not every log is called `.log`, and nothing here may narrow the answer by its name.** The
  /// daemon shipped a suffix rule of its own for a day and it hid `events.jsonl` — what the
  /// firewall blocked, which is the file to read when a task starts and then does nothing. The
  /// same rule written at this end would hide the same file, and no test of the daemon would see
  /// it.
  ///
  /// An empty list is a normal answer. A task whose state directory is gone, which is what `Stop`
  /// with purge does, has no logs; so does a name that is not a Porelo task.
  Future<List<Log>> logsOf(String task) async {
    final reply = await _call('Logs', {'task': task});
    final logs = reply['logs'];
    return logs is List ? logs.whereType<Map<String, dynamic>>().map(Log.from).toList() : const <Log>[];
  }

  /// Reads a task's log once.
  Future<List<String>> readLog(String task, String log) async =>
      _linesOf(await _call('Tail', {'task': task, 'log': log}));

  /// Follows a task's log as it is written.
  ///
  /// With [last], it starts from the log's last that many lines rather than its first; with
  /// [formatted], every line comes as the task's agent shows it, hidden ones left out. Both are sent
  /// only when given, so a Porelo older than them is asked what it knows.
  Stream<List<String>> tailLog(String task, String log, {int? last, bool formatted = false}) =>
      _callMore('Tail', {'task': task, 'log': log, 'last': ?last, if (formatted) 'formatted': true}).map(_linesOf);

  /// What [task]'s terminal session shows now, its last [last] lines, without attaching: nobody in
  /// the session sees anything happen. With [escapes], the lines keep the terminal's colours.
  Future<Screen> screen(String task, {required int last, bool escapes = false}) async =>
      Screen.from(await _call('Screen', {'task': task, 'last': last, if (escapes) 'escapes': true}));

  // --------------------------------------------------------------------- the gate

  /// What is waiting at a project's gate.
  ///
  /// [repository] is one of `Project.repositories`; without one a Porelo answers the project's own
  /// and an older one knows no other.
  Future<GateState> gate(String project, {String? upstream, String? repository}) async =>
      GateState.from(await _call('Pending', {'project': project, 'upstream': ?upstream, 'repository': ?repository}));

  /// What a pending push contains: a diff and a log, and, from a Porelo that ranks the review, its
  /// files in the order to show them and what the task that pushed was asked.
  ///
  /// `asked` is null where the machine does not say, an empty string where the task was started
  /// without an instruction; `files` is empty from a Porelo older than the ranked review.
  Future<({String diff, String log, List<ReviewFile> files, String? asked})> review(
    String project,
    String name, {
    String? upstream,
    String? against,
    String? repository,
  }) async {
    final reply = await _call('Review', {
      'project': project,
      'name': name,
      'upstream': ?upstream,
      'against': ?against,
      'repository': ?repository,
    });
    final diff = reply['diff'];
    final log = reply['log'];
    final files = reply['files'];
    final asked = reply['asked'];
    return (
      diff: diff is String ? diff : '',
      log: log is String ? log : '',
      files: files is List
          ? files.whereType<Map<String, dynamic>>().map(ReviewFile.from).toList()
          : const <ReviewFile>[],
      asked: asked is String ? asked : null,
    );
  }

  /// Forwards a pending push upstream.
  ///
  /// The only call that sends anything anywhere, and it makes the caller name the branch.
  Future<void> approve(
    String project,
    String name,
    String branch, {
    String? upstream,
    String? repository,
    String? commit,
  }) async => _call('Approve', {
    'project': project,
    'name': name,
    'branch': branch,
    'upstream': ?upstream,
    'repository': ?repository,
    'commit': ?commit,
  });

  /// Drops a pending push. The work stays in the mirror; only the request is gone.
  ///
  /// The task the work came from is told in its inbox, with [reason] when a person gave one. `told`
  /// is false when no task of that name has a mailbox any more, and null from a Porelo that does not
  /// say.
  Future<({bool? told})> reject(
    String project,
    String name, {
    String? upstream,
    String? repository,
    String? reason,
  }) async {
    final reply = await _call('Reject', {
      'project': project,
      'name': name,
      'upstream': ?upstream,
      'repository': ?repository,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
    final told = reply['told'];
    return (told: told is bool ? told : null);
  }

  // --------------------------------------------------------------------- clearance

  /// Blocked connections from every running task, as they happen.
  ///
  /// One subscription covers tasks started after the call, so an interface never has to discover
  /// and connect to each task's own socket.
  Stream<Prompt> prompts() => _callMore('Prompts').map(Prompt.from);

  /// Every message waiting for a person on this machine, or in one task's mailbox: never its text.
  Future<List<HeldMessage>> held({String? task}) async {
    final reply = await _call('Held', <String, dynamic>{'task': ?task});
    final messages = reply['messages'];
    return messages is List
        ? messages.whereType<Map<String, dynamic>>().map(HeldMessage.from).toList()
        : const <HeldMessage>[];
  }

  /// One message a person is asked to decide about, in full.
  Future<HeldMessageRead> readHeld(String task, String id) async =>
      HeldMessageRead.from(await _call('ReadHeld', <String, dynamic>{'task': task, 'id': id}));

  /// Releases one message, or refuses it for good; for one the filter refused, delivers it after
  /// all or keeps it refused.
  /// A refusal's [reason], the person's words, reaches the sender with it.
  Future<MessageRelease> release(String task, String id, {bool refuse = false, String? reason}) async =>
      MessageRelease.from(
        await _call('Release', <String, dynamic>{
          'task': task,
          'id': id,
          if (refuse) 'refuse': true,
          if (refuse && reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        }),
      );

  /// The peers [task] may address, and what a person decided about each.
  Future<List<TalkPeer>> peers(String task, String project) async {
    final reply = await _call('Peers', <String, dynamic>{'task': task, 'project': project});
    final peers = reply['peers'];
    return peers is List ? peers.whereType<Map<String, dynamic>>().map(TalkPeer.from).toList() : const <TalkPeer>[];
  }

  /// Lets [person] into [project]'s conversation with an account made for them, or gives it a new
  /// password with [reset]. **Answered once**: the login is in this reply and nowhere else.
  Future<MessagesJoined> joinMessages(String project, String person, {bool reset = false}) async => MessagesJoined.from(
    await _call('JoinMessages', <String, dynamic>{'project': project, 'person': person, if (reset) 'reset': true}),
  );

  /// Pending work [name] at [project]'s gate as a git bundle: what is on the pending ref and not on
  /// [branch]. Refused as `BundleTooLarge` above what one reply may carry.
  Future<({List<int> bundle, int bytes})> pendingBundle(
    String project,
    String name, {
    String? repository,
    String? branch,
  }) async {
    final reply = await _call('PendingBundle', <String, dynamic>{
      'project': project,
      'repository': ?repository,
      'name': name,
      'branch': ?branch,
    });
    final List<int> bundle;
    try {
      bundle = base64.decode(reply['bundle'] is String ? reply['bundle'] as String : '');
    } on FormatException {
      // Said as the machine answering wrongly, which a review shows, rather than thrown past it.
      throw const VarlinkException('org.fuin.porelo.Tasks1.PendingBundle', <String, dynamic>{
        'message': 'the bundle it sent is not base64',
      });
    }
    return (bundle: bundle, bytes: reply['bytes'] is int ? reply['bytes'] as int : 0);
  }

  /// Clears pending work [name] once [branch] on the upstream holds its commit, fetched with the
  /// machine's own key. Not landed changes nothing, and `detail` says why.
  Future<({bool landed, String commit, String detail})> landed(
    String project,
    String name, {
    String? repository,
    required String branch,
  }) async {
    final reply = await _call('Landed', <String, dynamic>{
      'project': project,
      'repository': ?repository,
      'name': name,
      'branch': branch,
    });
    return (
      landed: reply['landed'] == true,
      commit: reply['commit'] is String ? reply['commit'] as String : '',
      detail: reply['detail'] is String ? reply['detail'] as String : '',
    );
  }

  /// This machine's message key, for writing its `machine-signers` line into a project.
  Future<MachineKey> messageKey() async => MachineKey.from(await _call('MessageKey'));

  /// The repositories worked on without a project, in [defaultProject].
  Future<List<DefaultRepository>> defaultRepositories() async {
    final reply = await _call('DefaultRepositories');
    final listed = reply['repositories'];
    return listed is List
        ? listed.whereType<Map<String, dynamic>>().map(DefaultRepository.from).toList()
        : const <DefaultRepository>[];
  }

  /// Adds the repository at [upstream] to [defaultProject], under [name] where one is given. The
  /// same address again answers the one already there.
  Future<DefaultRepository> addToDefault(String upstream, {String? name}) async {
    final reply = await _call('AddToDefault', <String, dynamic>{
      'upstream': upstream,
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
    });
    final repository = reply['repository'];
    return DefaultRepository.from(repository is Map<String, dynamic> ? repository : const <String, dynamic>{});
  }

  /// Takes [name] out of [defaultProject]. Its mirror, and anything waiting in it, stay; the deploy
  /// key the machine had for it is forgotten there and answered, to be removed at its forge.
  Future<({bool removed, List<MachineDeployKey> keys})> removeFromDefault(String name) async {
    final reply = await _call('RemoveFromDefault', <String, dynamic>{'name': name});
    final keys = reply['keys'];
    return (
      removed: reply['removed'] == true,
      keys: keys is List
          ? keys.whereType<Map<String, dynamic>>().map(MachineDeployKey.from).toList()
          : const <MachineDeployKey>[],
    );
  }

  /// The keys a project file may hold, as this machine's Porelo knows them.
  Future<ProjectFileSchema> projectFileSchema() async => ProjectFileSchema.from(await _call('ProjectFileSchema'));

  /// Checks a draft `project.yml` against this machine.
  Future<ProjectFileCheck> checkProjectFile(String text) async =>
      ProjectFileCheck.from(await _call('CheckProjectFile', <String, dynamic>{'text': text}));

  /// Removes [person] from [project]'s conversation and reports any account kept.
  Future<MessageMemberRemoved> removeMessageMember(String project, String person) async => MessageMemberRemoved.from(
    await _call('RemoveMessageMember', <String, dynamic>{'project': project, 'person': person}),
  );

  /// Who has joined [project]'s conversation.
  Future<List<MessageMember>> messageMembers(String project) async {
    final reply = await _call('MessageMembers', <String, dynamic>{'project': project});
    final members = reply['members'];
    return members is List
        ? <MessageMember>[
            for (final each in members)
              if (each is Map<String, dynamic>) MessageMember.from(each),
          ]
        : const <MessageMember>[];
  }

  /// Holds a peer, releases it, or changes its mode; what is left out stays as it is.
  Future<TalkPeer> moderate(String task, String project, String name, {bool? held, String? mode}) async {
    final reply = await _call('Moderate', <String, dynamic>{
      'task': task,
      'project': project,
      'name': name,
      'held': ?held,
      'mode': ?mode,
    });
    return TalkPeer(
      name: reply['name'] is String ? reply['name'] as String : name,
      address: '',
      trust: '',
      perDay: 0,
      mode: reply['mode'] is String ? reply['mode'] as String : '',
      held: reply['held'] == true,
    );
  }

  /// Writes a person's own message into [task]'s conversation with [peer]. Written, not sent.
  Future<Said> say(String task, String peer, String text, {String kind = 'question', String? context}) async =>
      Said.from(
        await _call('Say', <String, dynamic>{
          'task': task,
          'peer': peer,
          'kind': kind,
          'text': text,
          'context': ?context,
        }),
      );

  /// Puts a person's own words straight into [task]'s inbox, where its agent reads them. Never
  /// leaves the machine, so neither signed nor filtered. Answers the file written.
  Future<String> tell(String task, String text) async {
    final reply = await _call('Tell', <String, dynamic>{'task': task, 'text': text});
    return reply['message'] is String ? reply['message'] as String : '';
  }

  /// Every destination declared on this machine, the one in force for each name first.
  Future<List<Destination>> destinations() async {
    final reply = await _call('Destinations', const <String, dynamic>{});
    final list = reply['destinations'];
    return list is List ? list.whereType<Map<String, dynamic>>().map(Destination.from).toList() : const <Destination>[];
  }

  /// Declares a destination in the user's own directory; with [dryRun], says what would be written.
  Future<({Destination destination, bool written})> writeDestination({
    required String name,
    required String upstream,
    String? label,
    String? authHeader,
    String? authPrefix,
    String? authQuery,
    bool dryRun = false,
  }) async {
    final reply = await _call('WriteDestination', <String, dynamic>{
      'name': name,
      'upstream': upstream,
      'label': ?label,
      'authHeader': ?authHeader,
      'authPrefix': ?authPrefix,
      'authQuery': ?authQuery,
      if (dryRun) 'dryRun': true,
    });
    final destination = reply['destination'];
    return (
      destination: Destination.from(destination is Map<String, dynamic> ? destination : const <String, dynamic>{}),
      written: reply['written'] == true,
    );
  }

  /// Removes the user's own declaration of a destination.
  Future<({bool removed, String file})> removeDestination(String name) async {
    final reply = await _call('RemoveDestination', <String, dynamic>{'name': name});
    return (removed: reply['removed'] == true, file: reply['file'] is String ? reply['file'] as String : '');
  }

  /// What a person has to authorize before work can use it: first what is open, then what changes.
  Stream<AuthorizationNeeded> authorizations() => _callMore('Authorizations').map(AuthorizationNeeded.from);

  /// Grants the authorization the vault entry [name] names, once, for this account's later tasks.
  /// Streams until it is settled: `needed` with the link, then granted, refused, expired or failed.
  Stream<AuthorizeProgress> authorize(String name) =>
      _callMore('Authorize', <String, dynamic>{'name': name}).map(AuthorizeProgress.from);

  /// What happens to messages in every mailbox, from now on. Replays nothing: [held] says what
  /// already waits.
  Stream<TalkEvent> talk() => _callMore('Talk').map(TalkEvent.from);

  /// Answers one prompt.
  ///
  /// [Prompt.key] goes back unchanged. A task that is not running has no watcher to tell, and
  /// that is refused rather than accepted and dropped.
  Future<bool> decide(Prompt prompt, {required bool allow}) async {
    final reply = await _call('Decide', {
      'task': prompt.task,
      'key': prompt.key,
      'address': prompt.destination,
      'allow': allow,
    });
    return reply['ok'] == true;
  }

  // --------------------------------------------------------------------- plumbing

  Future<Map<String, dynamic>> _call(
    String method, [
    Map<String, dynamic> parameters = const {},
    bool qualify = true,
  ]) async {
    final connection = await backend.open();
    try {
      return await connection.call(qualify ? '$interfaceName.$method' : method, parameters, answerWithin);
    } on VarlinkException catch (ex) {
      if (ex.isMethodNotFound) throw FeatureNotSupported(method);
      rethrow;
    } finally {
      await connection.close();
    }
  }

  Stream<Map<String, dynamic>> _callMore(String method, [Map<String, dynamic> parameters = const {}]) async* {
    final connection = await backend.open();
    try {
      yield* connection
          .callMore('$interfaceName.$method', parameters)
          .handleError(
            (Object error) => throw FeatureNotSupported(method),
            test: (dynamic error) => error is VarlinkException && error.isMethodNotFound,
          );
    } finally {
      await connection.close();
    }
  }

  static List<Task> _tasksOf(Map<String, dynamic> reply) {
    final tasks = reply['tasks'];
    return tasks is List ? tasks.whereType<Map<String, dynamic>>().map(Task.from).toList() : const [];
  }

  static List<String> _linesOf(Map<String, dynamic> reply) {
    final lines = reply['lines'];
    return lines is List ? lines.whereType<String>().toList() : const [];
  }
}

/// One reply from a task launch: a line, a step, or the result.
class StartProgress {
  /// A line the launch printed, or null on the final reply.
  final String? line;

  /// A streamed step, separate from a line of output.
  final StartStep? step;

  /// Steps retained in a final reply when the caller did not stream.
  final List<StartStep> steps;

  /// Container name of the started task, set on the final reply.
  final String? container;

  /// What the launch returned; zero is success. Set on the final reply.
  final int? exitCode;

  /// What Start did, or the refusal it answered with. Set on the final reply.
  final StartAction? action;

  /// Helpers started and recorded, for a task brought back. Null for one just created.
  final int? helpersStarted;

  /// How many helpers the task is recorded as having had.
  final int? helpersRecorded;

  /// What went wrong, per helper that did not come back.
  final List<String> problems;

  /// Set when the image the container was built from has changed since.
  final String imageDrift;

  /// Everything the launch printed. The contract fills it only for a caller that did not stream;
  /// one that streamed gathers the lines itself, because on a failure they are the reason.
  final List<String> output;

  /// Constructor taking every field.
  const StartProgress({
    this.line,
    this.step,
    this.steps = const <StartStep>[],
    this.container,
    this.exitCode,
    this.action,
    this.helpersStarted,
    this.helpersRecorded,
    this.problems = const <String>[],
    this.imageDrift = '',
    this.output = const <String>[],
  });

  /// The same reply, carrying [lines] as what the launch printed.
  StartProgress withOutput(List<String> lines) => StartProgress(
    line: line,
    step: step,
    steps: steps,
    container: container,
    exitCode: exitCode,
    action: action,
    helpersStarted: helpersStarted,
    helpersRecorded: helpersRecorded,
    problems: problems,
    imageDrift: imageDrift,
    output: List<String>.unmodifiable(lines),
  );

  /// Reads one from a reply.
  factory StartProgress.from(Map<String, dynamic> map) {
    final line = map['line'];
    final step = map['step'];
    final steps = map['steps'];
    final container = map['container'];
    final exitCode = map['exitCode'];
    final action = map['action'];
    final started = map['helpersStarted'];
    final recorded = map['helpersRecorded'];
    final problems = map['problems'];
    final drift = map['imageDrift'];
    final output = map['output'];
    return StartProgress(
      line: line is String ? line : null,
      step: step is Map<String, dynamic> ? StartStep.from(step) : null,
      steps: steps is List ? steps.whereType<Map<String, dynamic>>().map(StartStep.from).toList() : const <StartStep>[],
      container: container is String ? container : null,
      exitCode: exitCode is num ? exitCode.toInt() : null,
      action: action is String ? StartAction(action) : null,
      helpersStarted: started is num ? started.toInt() : null,
      helpersRecorded: recorded is num ? recorded.toInt() : null,
      problems: problems is List ? problems.whereType<String>().toList() : const <String>[],
      imageDrift: drift is String ? drift : '',
      output: output is List ? output.whereType<String>().toList() : const <String>[],
    );
  }

  /// Whether this is the last reply, carrying the result rather than output.
  bool get isResult => container != null || exitCode != null || action != null;
}

/// One reply from a build: a line it printed, or the result.
class PrepareProgress {
  /// A line the build printed, or null on the final reply.
  final String? line;

  /// `PREPARED`, `PREVIEWED`, `NO_SUCH_PROJECT` or `FAILED`. Null while output is still arriving.
  final String? outcome;

  /// The image that was built, or empty when nothing was.
  final String image;

  /// The depth actually used.
  ///
  /// **Read rather than assumed.** It comes back so a depth this build asked for and the daemon
  /// did not recognize is visible instead of being silently defaulted.
  final String rebuild;

  /// Why it failed, naming the step. Empty otherwise.
  final String detail;

  /// Constructor taking every field.
  const PrepareProgress({this.line, this.outcome, this.image = '', this.rebuild = '', this.detail = ''});

  /// Reads one from a reply.
  factory PrepareProgress.from(Map<String, dynamic> map) {
    final line = map['line'];
    final outcome = map['outcome'];
    return PrepareProgress(
      line: line is String ? line : null,
      outcome: outcome is String ? outcome : null,
      image: map['image'] is String ? map['image']! as String : '',
      rebuild: map['rebuild'] is String ? map['rebuild']! as String : '',
      detail: map['detail'] is String ? map['detail']! as String : '',
    );
  }

  /// Whether this is the last reply, carrying the result rather than output.
  bool get isResult => outcome != null;

  /// Whether an image was built.
  bool get built => outcome == 'PREPARED';
}
