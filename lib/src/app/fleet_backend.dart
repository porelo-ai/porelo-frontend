import 'dart:async';
import 'dart:io';

import 'package:porelo_frontend/client.dart';

import 'owned_process.dart';

/// Core's public result, independent of SSH authentication or daemon readiness.
enum HostUnlockState {
  /// Core confirmed the vault is open.
  unlocked,

  /// Core explicitly needs the local identity unlocked.
  waitingForKey,

  /// Core refused to unlock this host vault.
  refused,

  /// This installation cannot perform the agreed operation.
  unsupported,
}

/// A public vault outcome containing no key material or CLI output.
class HostUnlockResult {
  /// Carries the public result and a safe explanation from the adapter.
  const HostUnlockResult(this.state, [this.words]);

  /// Whether Core unlocked the host or needs the person's key.
  final HostUnlockState state;

  /// The public refusal, without process output or secret values.
  final String? words;
}

/// Delegates signing and host vault delivery entirely to Core.
abstract interface class HostUnlocker {
  /// Opens the host vault through the host's published SSH configuration.
  Future<HostUnlockResult> unlock(String host, String config);

  /// Cancels this host's in-flight signing or secret delivery and awaits cleanup.
  Future<void> cancel(String host);
}

/// Invokes the agreed Core command without parsing its output.
class CoreHostUnlocker implements HostUnlocker {
  /// Accepts a process boundary for tests and installations of Core.
  CoreHostUnlocker({Future<Process> Function(List<String>)? start, this.deadline = const Duration(seconds: 30)})
    : _start = start ?? _startCore;

  /// The bound on Core signing and delivery before its owned child is terminated.
  final Duration deadline;
  final Future<Process> Function(List<String>) _start;
  final Map<String, Process> _children = {};
  final Map<String, Future<HostUnlockResult>> _pending = {};
  final Map<String, int> _generations = {};
  static Future<Process> _startCore(List<String> command) => Process.start(command.first, command.sublist(1));

  @override
  Future<HostUnlockResult> unlock(String host, String config) => _pending.putIfAbsent(
    host,
    () => _unlock(host).whenComplete(() {
      _pending.remove(host);
    }),
  );

  Future<HostUnlockResult> _unlock(String host) async {
    final generation = _generations[host] ?? 0;
    Process? process;
    try {
      process = await _start(['porelo', 'host', 'unlock', host]);
      unawaited(process.stdout.drain<void>());
      unawaited(process.stderr.drain<void>());
      if (generation != (_generations[host] ?? 0)) {
        await stopOwnedProcess(process);
        return const HostUnlockResult(HostUnlockState.refused, 'Host unlock was cancelled.');
      }
      _children[host] = process;
      final code = await process.exitCode.timeout(deadline);
      return code == 0
          ? const HostUnlockResult(HostUnlockState.unlocked)
          : const HostUnlockResult(HostUnlockState.refused, 'Core could not unlock the host vault.');
    } on TimeoutException {
      if (process != null) await stopOwnedProcess(process);
      return const HostUnlockResult(HostUnlockState.refused, 'Core host unlock timed out.');
    } on ProcessException {
      return const HostUnlockResult(HostUnlockState.unsupported, 'Core host unlock is unavailable on this computer.');
    } finally {
      if (identical(_children[host], process)) _children.remove(host);
    }
  }

  @override
  Future<void> cancel(String host) async {
    _generations[host] = (_generations[host] ?? 0) + 1;
    final child = _children.remove(host);
    if (child != null) await stopOwnedProcess(child);
    await _pending[host];
  }
}

/// The backend, narrowed to what the frame asks of it.
///
/// The frame is judged on what a person sees when a backend answers, refuses or goes away, and
/// all three have to be producible in a widget test. A widget test runs on a fake clock, under
/// which a real socket makes no progress — so the wire is proven where it belongs, over a real
/// socket against the mock daemon in `test/client`, and the frame is proven against this.
///
/// It is deliberately no wider than what the frame asks for. Anything that grows it is probably a
/// screen reaching past the frame for something it should be asking the client for directly.
abstract class FleetBackend {
  /// What to call this machine. An action must never be ambiguous about where it acts.
  String get label;

  /// Opens it and answers what it says it is.
  ///
  /// Throws [VarlinkDisconnected] when there is nothing there, and [StateError] when it serves
  /// no interface this build understands.
  Future<ServiceInfo> open();

  /// Every task on it, running or stopped.
  Future<List<Task>> tasks();

  /// What the machine has to run agents with.
  ///
  /// Asked rather than assumed: what is installed is a property of the machine, and a name this
  /// build knew would be one that was never going to exist somewhere else. Three answers, and the
  /// third is the one nobody would go looking for — a binary installed and permanently hidden by
  /// another copy.
  Future<AgentsOnTheMachine> agentsOn();

  /// Every project on it.
  ///
  /// Asked for, never derived from the task list: a project that has never run anything would be
  /// invisible, and that is the one most likely to need attention.
  Future<List<Project>> projects();

  /// The task list, again whenever it changes.
  ///
  /// Errors with [FeatureNotSupported] against a backend too old to have `Watch`, which is a
  /// reason to stop expecting changes rather than a reason to stop.
  Stream<List<Task>> watch();

  /// Starts a task, streaming what it prints, one line per event.
  ///
  /// Long: building an image takes minutes, and an interface showing nothing for that long is
  /// indistinguishable from one that has hung. The stream ending is success; it errors when the
  /// launch returned a non-zero code, because what an exit code means is known here and not by
  /// whatever records the result.
  ///
  /// Yields detailed lines and the daemon's steps, without composing words about those steps.
  /// With [dryRun] it does everything up to starting the container and then reports, creating
  /// nothing. With [now] it ends once the task exists, without waiting for its image to be built.
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
  });

  /// Stops a task, keeping it and its workspace.
  Future<Stopped> stopTask(String task);

  /// Removes a task, or refuses and says why.
  ///
  /// Refusing is the interesting answer: a task holding commits that never reached the gate comes
  /// back as `HOLDS_WORK`, untouched, and the caller decides what that work is worth.
  Future<Removed> removeTask(String task, {bool? rescue, bool? force});

  /// Starts a listed task by its project file and its name within the project, and answers what
  /// Start did. Without waiting for a build, which `Tail` reads.
  ///
  /// [repository] is the one the task works in; none is sent to a machine that names none.
  Future<StartProgress> startAgain({required String project, required String task, String? repository});

  /// Sets or clears the caption a task reads by. **Nothing about its identity moves.**
  Future<Labelled> labelTask(String task, {String? label});

  /// Sends one part of a file handed to a running task; see [PoreloClient.handIn].
  Future<HandInPart> handIn(
    String task, {
    required String name,
    required int bytes,
    required String sha256,
    required int offset,
    required List<int> part,
  });

  /// Takes a handed-in file out of a running task again.
  Future<HandedFile> takeBack(String task, String name);

  /// The hand-in record under a task's name, of every run that carried it.
  Future<List<HandInEvent>> handIns(String task);

  /// What the vault holds, by name. **Never a value.**
  Future<VaultState> credentials();

  /// Shuts the vault. There is no `Unlock`: a daemon has no terminal for a passphrase.
  Future<Locked> lock();

  /// Enrolls this device as a keyslot. Proposed for Porelo's keyslots.
  Future<Enrolled> enrollDevice({required String name, required String share, required KeyslotStorage storage});

  /// Every credential that can open the vault. Proposed for Porelo's keyslots.
  Future<List<Keyslot>> keyslots();

  /// Revokes one keyslot. Proposed for Porelo's keyslots.
  Future<Revoked> revokeKeyslot(String id);

  /// Opens the vault with this device's share. Proposed for Porelo's keyslots.
  Future<UnlockedWithShare> unlockWithShare({required String share, int? minutes});

  /// Whether work can start, asked before anything is created.
  Future<Readiness> canStart({
    String? project,
    String? agent,
    String? task,
    String? repository,
    Map<String, String>? credentials,
  });

  /// Stops every running task and its helpers at once, or says what it would stop.
  ///
  /// **Stops and never removes.** What comes back is what survived, not what was cleared away.
  Future<Panicked> panic({bool? dryRun});

  /// Turns enforcement on or off on a task that is already running.
  Future<ClearanceSet> setClearance(String task, String mode, {bool? dryRun});

  /// Takes names back from a running task, and optionally from its project file.
  Future<Narrowed> narrowTask(String task, List<String> domains, {required Scope scope, bool? dryRun});

  /// What backups have been taken of a project's mirror. Newest first.
  Future<List<Backup>> backups(String project, {String? repository});

  /// What a task holds that never reached the gate. Asked for one task, never on a listing.
  Future<HeldWork> workHeld(String task);

  /// Asks the upstream how far behind a project's mirror is, now.
  Future<Synced> syncUpstream(String project, {String? repository});

  /// Fetches a followed project's repository now, rather than at the machine's next round.
  Future<List<Followed>> refreshProjects({String? project});

  /// Brings a task's repository at the gate up to its source, and tells its agent what moved.
  Future<TaskRefreshed> refreshTask(String task);

  /// Restores a mirror from a backup, or says what restoring would take.
  Future<Restored> restoreBackup(String project, String bundle, {bool? dryRun, bool? force, String? repository});

  /// Removes a backup, or says what removing it would take.
  Future<BackupDeleted> deleteBackup(String project, String bundle, {bool? dryRun});

  /// Builds a project's task image without starting anything. Streamed: a build takes minutes.
  Stream<PrepareProgress> prepare(String project, {String? agent, String? rebuild, bool? dryRun});

  /// Whether this machine can run a task, and what it is short of.
  Future<Health> doctor();

  /// Which providers this machine has, and where a credential for each belongs.
  Future<Providers> providers();

  /// Imports a credential an agent already holds on the machine. Moves no secret through here.
  Future<Imported> importCredential({String? agent, String? configDirectory});

  /// Which node this is, or empty from a daemon that does not answer.
  ///
  /// Only ever compared with another one. **Empty is never equal to empty here** — see
  /// `Machines`.
  Future<String> node();

  /// Removes what Porelo built for a project, or says what it would remove.
  ///
  /// **Never the project file, the checkout or the upstream**: those are the operator's, and
  /// `Deletion.keeps` names them so a confirmation can say so.
  Future<Deletion> unfollow(String project, {bool? dryRun, bool? force});

  /// Clears this machine of [project], or of everything with none; a dry run says what would go.
  Future<Cleared> clear({String? project, bool? dryRun, bool? force});

  /// Records a credential this machine may use; the value is stored on the machine, never here.
  Future<CredentialDeclared> credentialDeclare({
    required String kind,
    required String match,
    String? id,
    String? user,
    String? purpose,
    String? source,
    String? fromFile,
    bool? dryRun,
  });

  /// Forgets a credential record, leaving the secret where it is.
  Future<CredentialForgotten> credentialForget(String match);

  /// Which credential [url] would use and whether it would work, without touching the network.
  Future<CredentialChecked> credentialCheck(String url, {String? purpose});

  /// The ssh keys the machine's account already has, described without their values.
  Future<List<SshKey>> sshKeys();

  /// Records the one key of [host] a person confirmed, if the host still offers it.
  Future<HostKeyTrusted> trustHostKey(String host, String fingerprint);

  /// The repository and verified commit each project follows on this machine.
  Future<List<Followed>> following();

  /// Follows a project's repository and reconciles once; what came of it is the answer.
  Future<Followed> follow(
    String name,
    String url, {
    String? signedBy,
    List<String>? signers,
    bool? unverified,
    bool? acceptRewrite,
  });

  /// Blocked connections from every task on this machine, as they happen.
  ///
  /// Streaming only, and one subscription covers tasks started after the call.
  Stream<Prompt> prompts();

  /// Every message waiting for a person, or in one task's mailbox.
  Future<List<HeldMessage>> messagesHeld({String? task});

  /// One such message, in full.
  Future<HeldMessageRead> readHeld(String task, String id);

  /// Releases or refuses one; delivers a refused one after all, or keeps it refused.
  Future<MessageRelease> release(String task, String id, {bool refuse = false, String? reason});

  /// What happens to messages from now on.
  Stream<TalkEvent> talk();

  /// Grants the authorization vault entry [name] names, once, streaming until it is settled.
  Stream<AuthorizeProgress> authorize(String name);

  /// What a person has to authorize before work can use it: what is open, then what changes.
  Stream<AuthorizationNeeded> authorizations();

  /// Lets [person] into [project]'s conversation, or gives their account a new password with [reset].
  Future<MessagesJoined> joinMessages(String project, String person, {bool reset = false});

  /// Who has joined [project]'s conversation.
  Future<List<MessageMember>> messageMembers(String project);

  /// Removes a joined person and reports any account the transport kept.
  Future<MessageMemberRemoved> removeMessageMember(String project, String person);

  /// This machine's message key, for its `machine-signers` line.
  Future<MachineKey> messageKey();

  /// The repositories worked on without a project, in `default`.
  Future<List<DefaultRepository>> defaultRepositories();

  /// Adds the repository at [upstream] to `default`, under [name] where one is given.
  Future<DefaultRepository> addToDefault(String upstream, {String? name});

  /// Takes [name] out of `default`; its mirror stays, and the key the machine forgot is answered.
  Future<({bool removed, List<MachineDeployKey> keys})> removeFromDefault(String name);

  /// The contract, as the machine serves it: what it can be asked, read before a step that needs a
  /// newer Porelo rather than found out in the middle of it.
  Future<String> contract();

  /// Pending work at a project's gate as a git bundle, for a person to merge on their own computer.
  Future<({List<int> bundle, int bytes})> pendingBundle(
    String project,
    String name, {
    String? repository,
    String? branch,
  });

  /// Clears pending work once the upstream's [branch] holds it.
  Future<({bool landed, String commit, String detail})> landed(
    String project,
    String name, {
    String? repository,
    required String branch,
  });

  /// The keys a project file may hold, as this machine's Porelo knows them.
  Future<ProjectFileSchema> projectFileSchema();

  /// Checks a draft `project.yml` against this machine.
  Future<ProjectFileCheck> checkProjectFile(String text);

  /// Every destination declared on the machine, the one in force for each name first.
  Future<List<Destination>> destinations();

  /// Declares a destination in the user's own directory; with [dryRun] only says what would be.
  Future<({Destination destination, bool written})> writeDestination({
    required String name,
    required String upstream,
    String? label,
    String? authHeader,
    String? authPrefix,
    String? authQuery,
    bool dryRun = false,
  });

  /// Removes the user's own declaration of a destination.
  Future<({bool removed, String file})> removeDestination(String name);

  /// The peers a task may address, by its project's name.
  Future<List<TalkPeer>> peers(String task, String project);

  /// Holds or releases a peer, or changes its mode.
  Future<TalkPeer> moderate(String task, String project, String name, {bool? held, String? mode});

  /// Writes a person's own message to a task's peer.
  Future<Said> say(String task, String peer, String text, {String kind = 'question'});

  /// A person's own words into [task]'s inbox, where its agent reads them. Answers the file written.
  Future<String> tell(String task, String text);

  /// Answers one blocked connection.
  ///
  /// A task that is not running has no watcher to tell, and that is refused with `NoClearance`
  /// rather than accepted and dropped.
  Future<void> decide(Prompt prompt, {required bool allow});

  /// What a project's work may reach, and what is asked for and deliberately not given.
  ///
  /// With [repository], what that repository adds as well — grants a repository declares are added
  /// to the project's, never in place of them.
  Future<(List<EgressHost>, List<String>)> egressOf(String projectFile, {String? repository});

  /// The destination sets installed on this machine, and where they were found.
  Future<(List<EgressSet>, List<String>)> egressSets();

  /// Changes what a project's work may reach, or says what the change would do.
  ///
  /// **Nothing here reaches a running task**: a container's ruleset is built when it starts.
  Future<EgressChange> changeEgress(
    String projectFile, {
    List<String>? addSets,
    List<String>? removeSets,
    List<String>? addDomains,
    List<String>? removeDomains,
    bool? dryRun,
    String? repository,
  });

  /// Lets a **running** task reach names it could not reach before.
  ///
  /// The counterpart to [changeEgress], which reaches the next task and not this one. [scope] is
  /// required and has no default: this run, or this run and the project file.
  Future<Widened> widenTask(String task, List<String> domains, {required Scope scope, bool? dryRun});

  /// What is waiting at a project's gate.
  ///
  /// [projectFile] is `Project.name`: every method takes a project's name, never a path on a
  /// machine this end cannot see. A project the machine does not follow is listed and not asked
  /// about — a state to render, never a call to make anyway.
  ///
  /// [repository] names one of the project's repositories; without one the daemon answers the
  /// project's own.
  Future<GateState> gateOf(String projectFile, {String? repository});

  /// What one waiting push contains, so it can be judged before it is forwarded.
  ///
  /// [against] diffs against something other than the upstream's default branch.
  Future<({String diff, String log, List<ReviewFile> files, String? asked})> reviewOf(
    String projectFile,
    String name, {
    String? against,
    String? repository,
  });

  /// Forwards a waiting push upstream, onto a branch the caller names.
  ///
  /// **The only thing in this interface that sends anything anywhere**, and the branch is never
  /// inferred: a push forwarded onto a guess is one nobody decided about.
  Future<void> approve(String projectFile, String name, String branch, {String? repository, String? commit});

  /// Drops the request. The work stays in the mirror; only the asking is gone.
  Future<({bool? told})> reject(String projectFile, String name, {String? repository, String? reason});

  /// Which logs a task has, asked rather than assumed.
  ///
  /// An empty list is a normal answer: a task whose state directory is gone has none.
  Future<List<Log>> logsOf(String task);

  /// Follows one of a task's logs as it is written, a batch of lines per reply.
  ///
  /// The name comes from [logsOf] unchanged: it is a file in the task's state directory, never a
  /// path, and `Tail` refuses anything else. [last] and [formatted] are asked for only where the
  /// machine's `Tail` takes them; an older one reads from the start, raw.
  Stream<List<String>> tailLog(String task, String log, {int? last, bool formatted = false});

  /// What [task]'s terminal session shows now; [FeatureNotSupported] from a Porelo without `Screen`.
  Future<Screen> screen(String task, {required int last, bool escapes = false});
}

/// A real Porelo daemon, local or forwarded.
class PoreloBackend implements FleetBackend {
  /// Constructor taking where the daemon is.
  PoreloBackend(this.backend);

  /// The socket and its name.
  final Backend backend;

  PoreloClient? _client;

  @override
  String get label => backend.label;

  @override
  Future<ServiceInfo> open() async {
    final client = await PoreloClient.connect(backend);
    _client = client;
    // Another Porelo may answer now: what its `Tail` takes is asked again.
    _tailTakes = null;
    return client.info;
  }

  @override
  Future<List<Task>> tasks() => _opened().tasks();

  @override
  Future<AgentsOnTheMachine> agentsOn() => _opened().agents();

  @override
  Future<List<Project>> projects() => _opened().projects();

  @override
  Stream<List<Task>> watch() => _opened().watchTasks();

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
  }) async* {
    // Keep final output too, so a refusal returned without intermediate replies retains its words.
    var exitCode = 0;
    StartAction? action;
    final replies = _opened()
        .start(
          task: task,
          project: project,
          agent: agent,
          dryRun: dryRun,
          mode: mode,
          prompt: prompt,
          model: model,
          maxTurns: maxTurns,
          minutes: minutes,
          repository: repository,
          credentials: credentials,
          now: now,
        )
        .transform(startRefusalsSaid);
    await for (final progress in replies) {
      final line = progress.line;
      if (line != null) yield StartLine(line);
      for (final line in progress.output) {
        yield StartLine(line);
      }
      final step = progress.step;
      if (step != null) yield step;
      for (final step in progress.steps) {
        yield step;
      }
      if (progress.exitCode != null) exitCode = progress.exitCode!;
      if (progress.action != null) action = progress.action;
    }
    // A refusal is an ordinary final reply, and must not read as a start that worked.
    if (action != null && action.isKnown && !action.starts) throw StartRefused(action);
    if (exitCode != 0) throw OperationFailed(exitCode);
  }

  @override
  Future<Stopped> stopTask(String task) => _opened().stop(task);

  @override
  Future<Removed> removeTask(String task, {bool? rescue, bool? force}) =>
      _opened().remove(task, rescue: rescue, force: force);

  @override
  Future<StartProgress> startAgain({required String project, required String task, String? repository}) async {
    var last = const StartProgress();
    final printed = <String>[];
    final replies = _opened().start(project: project, task: task, repository: repository).transform(startRefusalsSaid);
    await for (final progress in replies) {
      final line = progress.line;
      if (line != null) printed.add(line);
      last = progress;
    }
    // The final reply carries only a code. What was printed before it is why, and dropping it left
    // "failed with exit code 70" where the machine had said which agent it wanted.
    return last.output.isEmpty ? last.withOutput(printed) : last;
  }

  @override
  Future<Labelled> labelTask(String task, {String? label}) => _opened().label(task, label: label);

  @override
  Future<HandInPart> handIn(
    String task, {
    required String name,
    required int bytes,
    required String sha256,
    required int offset,
    required List<int> part,
  }) => _opened().handIn(task, name: name, bytes: bytes, sha256: sha256, offset: offset, part: part);

  @override
  Future<HandedFile> takeBack(String task, String name) => _opened().takeBack(task, name);

  @override
  Future<List<HandInEvent>> handIns(String task) => _opened().handIns(task);

  @override
  Future<VaultState> credentials() => _opened().credentials();

  @override
  Future<Locked> lock() => _opened().lock();

  @override
  Future<Enrolled> enrollDevice({required String name, required String share, required KeyslotStorage storage}) =>
      _opened().enrollDevice(name: name, share: share, storage: storage);

  @override
  Future<List<Keyslot>> keyslots() => _opened().keyslots();

  @override
  Future<Revoked> revokeKeyslot(String id) => _opened().revokeKeyslot(id);

  @override
  Future<UnlockedWithShare> unlockWithShare({required String share, int? minutes}) =>
      _opened().unlockWithShare(share: share, minutes: minutes);

  @override
  Future<Readiness> canStart({
    String? project,
    String? agent,
    String? task,
    String? repository,
    Map<String, String>? credentials,
  }) =>
      _opened().canStart(project: project, agent: agent, task: task, repository: repository, credentials: credentials);

  @override
  Future<Panicked> panic({bool? dryRun}) => _opened().panic(dryRun: dryRun);

  @override
  Future<ClearanceSet> setClearance(String task, String mode, {bool? dryRun}) =>
      _opened().setClearance(task, mode, dryRun: dryRun);

  @override
  Future<Narrowed> narrowTask(String task, List<String> domains, {required Scope scope, bool? dryRun}) =>
      _opened().narrowTask(task, domains, scope: scope, dryRun: dryRun);

  @override
  Future<List<Backup>> backups(String project, {String? repository}) =>
      _opened().backups(project, repository: repository);

  @override
  Future<HeldWork> workHeld(String task) => _opened().workHeld(task);

  @override
  Future<Synced> syncUpstream(String project, {String? repository}) =>
      _opened().syncUpstream(project, repository: repository);

  @override
  Future<List<Followed>> refreshProjects({String? project}) => _opened().refreshProjects(project: project);

  @override
  Future<TaskRefreshed> refreshTask(String task) => _opened().refreshTask(task);

  @override
  Future<Restored> restoreBackup(String project, String bundle, {bool? dryRun, bool? force, String? repository}) =>
      _opened().restoreBackup(project, bundle, dryRun: dryRun, force: force, repository: repository);

  @override
  Future<BackupDeleted> deleteBackup(String project, String bundle, {bool? dryRun}) =>
      _opened().deleteBackup(project, bundle, dryRun: dryRun);

  @override
  Stream<PrepareProgress> prepare(String project, {String? agent, String? rebuild, bool? dryRun}) =>
      _opened().prepare(project, agent: agent, rebuild: rebuild, dryRun: dryRun);

  @override
  Future<Health> doctor() => _opened().doctor();

  @override
  Future<Providers> providers() => _opened().providers();

  @override
  Future<Imported> importCredential({String? agent, String? configDirectory}) =>
      _opened().importCredential(agent: agent, configDirectory: configDirectory);

  @override
  Future<String> node() => _opened().node();

  @override
  Future<Deletion> unfollow(String project, {bool? dryRun, bool? force}) =>
      _opened().unfollow(project, dryRun: dryRun, force: force);

  @override
  Future<Cleared> clear({String? project, bool? dryRun, bool? force}) =>
      _opened().clear(project: project, dryRun: dryRun, force: force);

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
  }) => _opened().credentialDeclare(
    kind: kind,
    match: match,
    id: id,
    user: user,
    purpose: purpose,
    source: source,
    fromFile: fromFile,
    dryRun: dryRun,
  );

  @override
  Future<CredentialForgotten> credentialForget(String match) => _opened().credentialForget(match);

  @override
  Future<CredentialChecked> credentialCheck(String url, {String? purpose}) =>
      _opened().credentialCheck(url, purpose: purpose);

  @override
  Future<List<SshKey>> sshKeys() => _opened().sshKeys();

  @override
  Future<HostKeyTrusted> trustHostKey(String host, String fingerprint) => _opened().trustHostKey(host, fingerprint);

  @override
  Future<List<Followed>> following() => _opened().following();

  @override
  Future<Followed> follow(
    String name,
    String url, {
    String? signedBy,
    List<String>? signers,
    bool? unverified,
    bool? acceptRewrite,
  }) => _opened().follow(
    name,
    url,
    signedBy: signedBy,
    signers: signers,
    unverified: unverified,
    acceptRewrite: acceptRewrite,
  );

  @override
  Stream<Prompt> prompts() => _opened().prompts();

  @override
  Future<List<HeldMessage>> messagesHeld({String? task}) => _opened().held(task: task);

  @override
  Future<HeldMessageRead> readHeld(String task, String id) => _opened().readHeld(task, id);

  @override
  Future<MessageRelease> release(String task, String id, {bool refuse = false, String? reason}) =>
      _opened().release(task, id, refuse: refuse, reason: reason);

  @override
  Stream<TalkEvent> talk() => _opened().talk();

  @override
  Stream<AuthorizeProgress> authorize(String name) => _opened().authorize(name);

  @override
  Stream<AuthorizationNeeded> authorizations() => _opened().authorizations();

  @override
  Future<MessagesJoined> joinMessages(String project, String person, {bool reset = false}) =>
      _opened().joinMessages(project, person, reset: reset);

  @override
  Future<List<MessageMember>> messageMembers(String project) => _opened().messageMembers(project);

  @override
  Future<MessageMemberRemoved> removeMessageMember(String project, String person) =>
      _opened().removeMessageMember(project, person);

  @override
  Future<MachineKey> messageKey() => _opened().messageKey();

  @override
  Future<List<DefaultRepository>> defaultRepositories() => _opened().defaultRepositories();

  @override
  Future<DefaultRepository> addToDefault(String upstream, {String? name}) =>
      _opened().addToDefault(upstream, name: name);

  @override
  Future<({bool removed, List<MachineDeployKey> keys})> removeFromDefault(String name) =>
      _opened().removeFromDefault(name);

  @override
  Future<String> contract() => _opened().contract();

  @override
  Future<({List<int> bundle, int bytes})> pendingBundle(
    String project,
    String name, {
    String? repository,
    String? branch,
  }) => _opened().pendingBundle(project, name, repository: repository, branch: branch);

  @override
  Future<({bool landed, String commit, String detail})> landed(
    String project,
    String name, {
    String? repository,
    required String branch,
  }) => _opened().landed(project, name, repository: repository, branch: branch);

  @override
  Future<ProjectFileSchema> projectFileSchema() => _opened().projectFileSchema();

  @override
  Future<ProjectFileCheck> checkProjectFile(String text) => _opened().checkProjectFile(text);

  @override
  Future<List<Destination>> destinations() => _opened().destinations();

  @override
  Future<({Destination destination, bool written})> writeDestination({
    required String name,
    required String upstream,
    String? label,
    String? authHeader,
    String? authPrefix,
    String? authQuery,
    bool dryRun = false,
  }) => _opened().writeDestination(
    name: name,
    upstream: upstream,
    label: label,
    authHeader: authHeader,
    authPrefix: authPrefix,
    authQuery: authQuery,
    dryRun: dryRun,
  );

  @override
  Future<({bool removed, String file})> removeDestination(String name) => _opened().removeDestination(name);

  @override
  Future<List<TalkPeer>> peers(String task, String project) => _opened().peers(task, project);

  @override
  Future<TalkPeer> moderate(String task, String project, String name, {bool? held, String? mode}) =>
      _opened().moderate(task, project, name, held: held, mode: mode);

  @override
  Future<String> tell(String task, String text) => _opened().tell(task, text);

  @override
  Future<Said> say(String task, String peer, String text, {String kind = 'question'}) =>
      _opened().say(task, peer, text, kind: kind);

  @override
  Future<void> decide(Prompt prompt, {required bool allow}) async => _opened().decide(prompt, allow: allow);

  @override
  Future<(List<EgressHost>, List<String>)> egressOf(String projectFile, {String? repository}) =>
      _opened().egress(projectFile, repository: repository);

  @override
  Future<(List<EgressSet>, List<String>)> egressSets() => _opened().sets();

  @override
  Future<EgressChange> changeEgress(
    String projectFile, {
    List<String>? addSets,
    List<String>? removeSets,
    List<String>? addDomains,
    List<String>? removeDomains,
    bool? dryRun,
    String? repository,
  }) => _opened().setEgress(
    projectFile,
    addSets: addSets,
    removeSets: removeSets,
    addDomains: addDomains,
    removeDomains: removeDomains,
    dryRun: dryRun,
    repository: repository,
  );

  @override
  Future<Widened> widenTask(String task, List<String> domains, {required Scope scope, bool? dryRun}) =>
      _opened().widenTask(task, domains, scope: scope, dryRun: dryRun);

  @override
  Future<GateState> gateOf(String projectFile, {String? repository}) =>
      _opened().gate(projectFile, repository: repository);

  @override
  Future<({String diff, String log, List<ReviewFile> files, String? asked})> reviewOf(
    String projectFile,
    String name, {
    String? against,
    String? repository,
  }) async {
    return _opened().review(projectFile, name, against: against, repository: repository);
  }

  @override
  Future<void> approve(String projectFile, String name, String branch, {String? repository, String? commit}) =>
      _opened().approve(projectFile, name, branch, repository: repository, commit: commit);

  @override
  Future<({bool? told})> reject(String projectFile, String name, {String? repository, String? reason}) =>
      _opened().reject(projectFile, name, repository: repository, reason: reason);

  @override
  Future<List<Log>> logsOf(String task) => _opened().logsOf(task);

  @override
  Stream<List<String>> tailLog(String task, String log, {int? last, bool formatted = false}) async* {
    final takes = await (_tailTakes ??= _whatTailTakes());
    yield* _opened().tailLog(
      task,
      log,
      last: takes.contains('last') ? last : null,
      formatted: formatted && takes.contains('formatted'),
    );
  }

  Future<Set<String>>? _tailTakes;

  @override
  Future<Screen> screen(String task, {required int last, bool escapes = false}) =>
      _opened().screen(task, last: last, escapes: escapes);

  /// Which of `last` and `formatted` this machine's `Tail` takes, read off its contract once.
  Future<Set<String>> _whatTailTakes() async {
    try {
      final parameters =
          RegExp(r'method Tail\((.*?)\)\s*->', dotAll: true).firstMatch(await contract())?.group(1) ?? '';
      return <String>{
        for (final each in const <String>['last', 'formatted'])
          if (RegExp('\\b$each\\s*:').hasMatch(parameters)) each,
      };
    } on Object {
      // Not known this time; asked again on the next tail rather than remembered as nothing.
      _tailTakes = null;
      return const <String>{};
    }
  }

  /// Core's verdict on the registry checkout; see [PoreloClient.registryRead].
  ///
  /// Only on [PoreloBackend], not on [FleetBackend]: the checkout is a folder on this computer, so only the
  /// daemon on this computer is ever asked about it.
  Future<RegistryRead> registryRead(String checkout) => _opened().registryRead(checkout);

  /// One registry change written and signed by Core; see [PoreloClient.registryFile].
  Future<RegistryFiled> registryFile(String checkout, {required String kind, String? host, String? person}) =>
      _opened().registryFile(checkout, kind: kind, host: host, person: person);

  PoreloClient _opened() {
    final client = _client;
    if (client == null) throw StateError('open() has not answered yet');
    return client;
  }
}

/// A build, as lines, so it runs through the same machinery a launch does.
///
/// **An extension rather than a member**, so every backend gets it and no fake has to reimplement
/// shaping that is not the backend's job.
extension BuildingAnEnvironment on FleetBackend {
  /// The same build, as lines.
  ///
  /// **The stream erroring is how a failure reaches an operation**, which is what puts the failed
  /// step in the record and keeps it readable afterwards. Nothing else has to know what an outcome
  /// means.
  Stream<String> buildEnvironment(String project, {String? agent, String? rebuild}) async* {
    var failed = '';
    await for (final progress in prepare(project, agent: agent, rebuild: rebuild)) {
      final line = progress.line;
      if (line != null) yield line;
      if (progress.isResult && !progress.built) {
        failed = progress.detail.isEmpty ? progress.outcome! : progress.detail;
      }
    }
    if (failed.isNotEmpty) throw PreparationFailed(failed);
  }
}

/// A build that did not produce an image.
///
/// **It carries the step rather than a code.** A build fails at a line of a Containerfile, and the
/// one thing somebody needs is which line — an exit code would send them to the output to find out
/// what this already knows.
class PreparationFailed implements Exception {
  /// Constructor taking what the daemon said, naming the step.
  const PreparationFailed(this.step);

  /// The step that failed, in the daemon's own words.
  final String step;

  @override
  String toString() => step;
}

/// A `Start` the machine refused, by name.
class StartRefused implements Exception {
  /// Constructor taking the refusal.
  const StartRefused(this.action);

  /// What Start answered instead of starting.
  final StartAction action;

  @override
  String toString() => switch (action) {
    StartAction.running => 'It is already running, so nothing was started.',
    StartAction.needsVault => 'The vault is locked. Unlock it, then start again.',
    StartAction.supersededName => 'It is from before one container per task, and can only be removed.',
    StartAction.notReady => 'This project is not ready to start work.',
    StartAction.predatesRestart =>
      'It was started before this machine restarted, so it cannot be started again. '
          'Copy its workspace out, then remove it.',
    _ => 'Refused: ${action.label}.',
  };
}

/// Turns `Start`'s named refusals into exceptions that say them in words: `NoSuchDestination` into
/// [NoSuchDestination], `EarlierWorkWaits` into [EarlierWorkWaits], `UpstreamUnreadable` into
/// [UpstreamUnreadable]. Any other error passes as it came.
final StreamTransformer<StartProgress, StartProgress> startRefusalsSaid =
    StreamTransformer<StartProgress, StartProgress>.fromHandlers(
      handleError: (error, stack, sink) => sink.addError(switch (error) {
        VarlinkException(simpleName: 'NoSuchDestination') => NoSuchDestination('${error.parameters['name'] ?? ''}'),
        VarlinkException(simpleName: 'EarlierWorkWaits') => EarlierWorkWaits(
          '${error.parameters['task'] ?? ''}',
          commit: '${error.parameters['commit'] ?? ''}',
          subject: '${error.parameters['subject'] ?? ''}',
        ),
        VarlinkException(simpleName: 'UpstreamUnreadable') => UpstreamUnreadable(
          '${error.parameters['cause'] ?? ''}',
          detail: '${error.parameters['detail'] ?? ''}',
          fix: '${error.parameters['fix'] ?? ''}',
        ),
        _ => error,
      }, stack),
    );

/// Start refused because the task's earlier work still waits at the gate, before anything was
/// created. Said in words, naming that work: it is decided at the gate, and then the task starts.
class EarlierWorkWaits implements Exception {
  /// Constructor taking the task and the work that waits, as the machine named them.
  const EarlierWorkWaits(this.task, {this.commit = '', this.subject = ''});

  /// The task that was not started.
  final String task;

  /// The waiting work's commit, in full; empty when the machine did not name it.
  final String commit;

  /// The waiting work's subject line; empty when the machine did not name it.
  final String subject;

  @override
  String toString() {
    final short = commit.length > 7 ? commit.substring(0, 7) : commit;
    final work = <String>[if (short.isNotEmpty) short, if (subject.isNotEmpty) '"$subject"'].join(' ');
    return '${task.isEmpty ? 'It' : task} was not started: its earlier work '
        '${work.isEmpty ? '' : '$work '}still waits at the gate. Forward it or drop it there, then '
        'start again.';
  }
}

/// Start refused a repository whose upstream it could not read, with no mirror yet to start from,
/// before anything was created. Said as the cause, what the machine tried, and the command that
/// fixes it.
class UpstreamUnreadable implements Exception {
  /// Constructor taking the cause, what was tried and the fix, as the machine named them.
  const UpstreamUnreadable(this.cause, {this.detail = '', this.fix = ''});

  /// `KEY_REFUSED`, `NOT_FOUND`, `UNREACHABLE` or `UNREADABLE`, or `UNKNOWN_HOST_KEY` for a host
  /// whose key changed since it was trusted; a cause this build does not know is said by the rest.
  final String cause;

  /// What was tried, in the machine's own words; empty when it said nothing.
  final String detail;

  /// The command that helps, or empty.
  final String fix;

  @override
  String toString() {
    final why = switch (cause) {
      'KEY_REFUSED' => 'The repository’s host refused what this machine offered for it.',
      'NOT_FOUND' => 'The host has no such repository, or none this credential may read.',
      'UNREACHABLE' => 'Nothing answered from the repository’s host within ten seconds.',
      'UNKNOWN_HOST_KEY' =>
        'The repository’s host offers another key than the one this machine remembers. That is what '
            'somebody in between looks like: find out why before going on.',
      _ => 'The repository could not be read.',
    };
    final tried = detail.trim().isEmpty ? '' : ' ${detail.trim()}${detail.trim().endsWith('.') ? '' : '.'}';
    final then = fix.trim().isEmpty ? '' : " Run '${fix.trim()}', then start again.";
    return '$why Nothing was started.$tried$then';
  }
}

/// Start refused a credential for a destination the machine does not declare, before anything
/// existed. Said in words: nothing was created, so there is nothing to clear up or read.
class NoSuchDestination implements Exception {
  /// Constructor taking the credential, as the machine named it.
  const NoSuchDestination(this.credential);

  /// The vault entry whose destination nobody declared: measured, the error's `name` is the entry,
  /// not the destination. Empty when the machine did not name it.
  final String credential;

  @override
  String toString() => credential.isEmpty
      ? 'A credential is for a destination this machine does not declare. Nothing was started.'
      : 'The credential $credential is for a destination this machine does not declare. Nothing was '
            'started; add the destination under Destinations, or give the entry for another.';
}

/// A launch that ran and came back with something other than zero.
///
/// Not a fault in the client and not a lost backend: the operation ran, and it failed. It gets
/// said in the same place a success would have been said.
class OperationFailed implements Exception {
  /// Constructor taking what the launch returned.
  const OperationFailed(this.exitCode);

  /// What the launch returned. Never zero.
  final int exitCode;

  /// Whether there is a log worth offering.
  ///
  /// Two of the bands are not failed runs at all. `69` means the run was **refused before
  /// anything was created**, so there is nothing to read — offering a log view there opens an
  /// empty window on a file that was never written.
  bool get leftALog => exitCode != 69;

  /// Whether the run was stopped by its own time limit rather than by going wrong.
  ///
  /// The log is kept, deliberately, and what it managed to do is usually the interesting part.
  bool get ranOutOfTime => exitCode == 124;

  /// Whether nothing ran, as opposed to something running badly.
  ///
  /// Nothing was created either: no container, no workspace, nothing to clear up. More than one
  /// thing answers `69` — no agent installed, and an unattended run whose credential could not be
  /// read — so **the reason is in the output and is never guessed at here.** `Start` has no
  /// outcome vocabulary, which is the gap this band is standing in for.
  bool get nothingRan => exitCode == 69;

  @override
  String toString() => switch (exitCode) {
    // Four bands, not two. Reading every non-zero code as "it failed" throws away the two
    // that are not failures of the work at all.
    124 =>
      'It ran out of the time it was given and was stopped. What it managed to do is '
          'in the log.',
    // Not "no agent is installed": more than one refusal answers 69, and the daemon prints
    // which. Naming one of them here would be wrong exactly when it was believed.
    69 =>
      'Nothing ran, and nothing was created. It was refused before it began; '
          'what was refused is in the output above.',
    _ => 'The agent exited with code $exitCode.',
  };
}
