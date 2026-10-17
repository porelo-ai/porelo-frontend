/// What became of a stop or a removal.
///
/// **Not an enum, deliberately.** The contract says adding a value is not a breaking change and
/// that a client must render one it does not recognize rather than fail on it. A Dart enum with
/// no fallback case is precisely how that rule gets broken - it would look correct until a
/// routine backend release. So this carries the raw name, compares by it, and tells the caller
/// whether it is one of the values this build knows.
class Outcome {
  /// The name exactly as the backend sent it.
  final String name;

  /// Constructor with the wire value.
  const Outcome(this.name);

  /// The name is not a task Porelo created, so nothing was touched.
  static const notATask = Outcome('NOT_A_TASK');

  /// There was nothing of the task to stop.
  static const nothingToStop = Outcome('NOTHING_TO_STOP');

  /// The task was stopped and kept, workspace and all.
  static const stopped = Outcome('STOPPED');

  /// The task holds work that never reached the gate, so nothing was touched.
  static const holdsWork = Outcome('HOLDS_WORK');

  /// Nothing could say whether the task holds work, so it was left as it was.
  static const nothingKnows = Outcome('NOTHING_KNOWS');

  /// The task is already down, so what it holds cannot be read out of it to rescue.
  static const rescueNeedsItRunning = Outcome('RESCUE_NEEDS_IT_RUNNING');

  /// Rescuing what the task held failed, so nothing was removed.
  static const rescueFailed = Outcome('RESCUE_FAILED');

  /// The task was removed.
  static const removed = Outcome('REMOVED');

  /// The task is still running, so nothing was removed.
  static const stillRunning = Outcome('STILL_RUNNING');

  /// Every value this build was written against.
  static const known = <Outcome>[
    notATask,
    nothingToStop,
    stopped,
    holdsWork,
    nothingKnows,
    rescueNeedsItRunning,
    rescueFailed,
    removed,
    stillRunning,
  ];

  /// Whether this build knows what this value means.
  ///
  /// An interface should still show an unknown one - the backend chose to send it - but it cannot
  /// claim to explain it.
  bool get isKnown => known.contains(this);

  /// The value as a phrase, for a person: `holds work`, and an unknown value lowercased rather
  /// than hidden.
  String get label => name.toLowerCase().replaceAll('_', ' ');

  @override
  bool operator ==(Object other) => other is Outcome && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => name;
}

/// What `Start` would do to one task, answered before anybody presses it.
///
/// Not an enum, by the rule [Outcome] states: the contract says this set will grow.
class StartAction {
  /// The name exactly as the backend sent it; empty from a daemon too old to say.
  final String name;

  /// Constructor with the wire value.
  const StartAction(this.name);

  /// Nothing exists under this name, and Start creates it.
  static const create = StartAction('CREATE');

  /// It is stopped, and Start brings it back with its workspace.
  static const resume = StartAction('RESUME');

  /// It is already running, and Start refuses.
  static const running = StartAction('RUNNING');

  /// It would come back, but the vault holding its gate token is locked.
  static const needsVault = StartAction('NEEDS_VAULT');

  /// Its name is from before one container per task, so it only removes.
  static const supersededName = StartAction('SUPERSEDED_NAME');

  /// Something not specific to this task is in the way; `startDetail` says what.
  static const notReady = StartAction('NOT_READY');

  /// It was started before this machine restarted: its sockets went with the restart, so it cannot
  /// come back. `startDetail` says how to copy its workspace out before removing it.
  static const predatesRestart = StartAction('PREDATES_RESTART');

  /// Every value this build was written against.
  static const known = <StartAction>[create, resume, running, needsVault, supersededName, notReady, predatesRestart];

  /// Whether this build knows what this value means.
  bool get isKnown => known.contains(this);

  /// Whether the daemon said anything at all.
  bool get said => name.isNotEmpty;

  /// Whether Start would do something rather than refuse.
  bool get starts => this == create || this == resume;

  /// The value as a phrase, for a person.
  String get label => name.toLowerCase().replaceAll('_', ' ');

  @override
  bool operator ==(Object other) => other is StartAction && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => name;
}

/// What the work is doing, beside — never instead of — the runtime's own words.
///
/// Deliberately not a Dart enum, by the same rule as [Outcome]: adding a value is not a breaking
/// change, so a closed enum is a client that breaks on a routine release.
class Activity {
  /// Constructor taking the name as the contract spells it.
  const Activity(this.name);

  /// The value as it came.
  final String name;

  /// Its container is not up. Stopped, finished or killed — all three.
  static const dead = Activity('DEAD');

  /// Waiting for a person to answer something. **Said by whatever asked**, never guessed from how
  /// long it has been quiet. [Task.waitingFor] says what about.
  static const waiting = Activity('WAITING');

  /// Producing output.
  static const working = Activity('WORKING');

  /// Up, producing nothing, and not waiting for anybody as far as anything can tell.
  static const idle = Activity('IDLE');

  /// Its agent has ended, whatever else the container does: [Task.agentEnded] says how. It
  /// wins over working and idle, which an ended agent's container can still look like.
  static const ended = Activity('ENDED');

  /// Up, and nothing on this side can see what it is doing.
  ///
  /// The normal answer for a task somebody attached a terminal to: its work goes to that terminal
  /// and not to anything the daemon reads. **Never render this as idle** — a state that is
  /// silently wrong is worse than one that says it does not know.
  static const unknown = Activity('UNKNOWN');

  /// The values this build knows. Not a validation list.
  static const known = <Activity>[dead, waiting, working, idle, ended, unknown];

  /// Whether this build knows what it means.
  bool get recognized => known.any((value) => value.name == name);

  /// Words for a person, unrecognized values included.
  String get label => switch (name) {
    'DEAD' => 'not running',
    'WAITING' => 'waiting',
    'WORKING' => 'working',
    'IDLE' => 'idle',
    'ENDED' => 'its agent ended',
    'UNKNOWN' => 'cannot be seen',
    '' => 'not recorded',
    _ => name.toLowerCase().replaceAll('_', ' '),
  };

  @override
  bool operator ==(Object other) => other is Activity && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => name;
}

/// How somebody is meant to be involved in a task.
class Mode {
  /// Constructor taking the name as the contract spells it.
  const Mode(this.name);

  /// The value as it came.
  final String name;

  /// A terminal in the container, driven by hand.
  static const shell = Mode('SHELL');

  /// The agent's own session, attached, with a person working through it.
  static const agent = Mode('AGENT');

  /// Started with a prompt and left to run. Nobody is expected to be watching.
  static const unattended = Mode('UNATTENDED');

  /// The values this build knows.
  static const known = <Mode>[shell, agent, unattended];

  /// Whether this build knows what it means.
  bool get recognized => known.any((value) => value.name == name);

  /// Words for a person.
  String get label => switch (name) {
    'SHELL' => 'a shell, driven by hand',
    'AGENT' => 'an agent session, worked through',
    'UNATTENDED' => 'unattended, against a prompt',
    '' => 'not recorded',
    _ => name.toLowerCase().replaceAll('_', ' '),
  };

  @override
  bool operator ==(Object other) => other is Mode && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => name;
}

/// One task on the machine, running or not.
class Task {
  /// Container name, which every other call takes.
  ///
  /// **The identity.** It is what `Start`, `Stop`, `Tail` and every other call are given, and
  /// what the gate ref, the workspace and the log files are built from. Nothing moves it.
  final String name;

  /// Its name within the project, which is what `Start` takes; [name] is the container it made.
  ///
  /// **Carried, never cut from [name]**: the two are related by a rule Porelo owns and changes.
  final String task;

  /// A caption somebody set, or empty.
  ///
  /// **Beside the identity, never instead of it.** Empty is the ordinary state — every task has
  /// none until somebody types one — and a task with none shows its real name. Renaming was asked
  /// for and is not what anybody wanted: it would move a gate ref with unreviewed pushes behind
  /// it.
  final String label;

  /// Project it belongs to, or empty when nothing recorded one.
  final String project;

  /// `offline`, `guarded`, `online`, or empty.
  final String securityClass;

  /// The container runtime's own words. **Free text for a person; never parse it.**
  final String state;

  /// Whether the runtime says it is up.
  final bool running;

  /// How many recorded helper processes are alive.
  ///
  /// A container that is up with no helpers has lost its gate or its clearance watcher, which is
  /// not the same thing as a healthy task.
  final int helpers;

  /// Which agent is running in it, by the name `Agents` reports. Empty when nothing recorded one.
  final String agent;

  /// The provider its agent was brokered to, by the name `Providers` reports. Empty when it was
  /// brokered to none, or a Porelo that did not record it started the task.
  final String provider;

  /// How somebody is meant to be involved.
  final Mode mode;

  /// What an unattended task was asked to do. Kept after it has finished.
  final String prompt;

  /// The ref its work goes to, such as `refs/porelo/incoming/shell`.
  final String branch;

  /// When the **current** state began, ISO-8601.
  ///
  /// Empty when the runtime cannot say — a container created and never started answers a zero
  /// time, which renders as a date centuries out. Compute "idle for forty minutes" from this and
  /// never from [state].
  final String since;

  /// What the work is doing, beside [state].
  final Activity activity;

  /// What is enforcing this task's egress: `prompt`, `allow`, `deny` or `off`.
  ///
  /// Empty when nothing recorded it, which is every task started before the field existed —
  /// render the absence rather than guessing `prompt`.
  ///
  /// **`off` is the one to mark wherever the task appears.** Nothing asks and nothing is refused:
  /// the firewall is loaded and no decision is ever put to anybody. Somebody chose that
  /// deliberately, and showing such a run like any other hides the choice.
  final String clearance;

  /// Whether nothing will ever be asked about what this task reaches.
  bool get unenforced => clearance == 'off';

  /// What it is waiting to be told, when [activity] is `WAITING`. A destination, such as
  /// `api.example.test:443`.
  final String waitingFor;

  /// Whether this task's own work is waiting at the gate: `1` when it is, `0` otherwise.
  ///
  /// **An `online` task always answers `0`, and that is not a smaller number** — its ref is
  /// `refs/heads/<task>` and nothing is ever reviewed, so it is a question the class does not
  /// have.
  ///
  /// Answered here rather than joined, because there is no join to make: [name] is a *container*
  /// name and `PendingPush.name` is a *task* name, and several containers over time share one
  /// ref. Anything lined up from the two would be right for at most one of them. Porelo offered
  /// the field the other way round, went to build it, and withdrew it for that reason.
  final int waiting;

  /// Whether this task's own work is waiting for somebody to review it.
  bool get hasWorkWaiting => waiting > 0;

  /// What `Start` would do to it, without doing it. Empty from a daemon too old to say.
  final StartAction startAction;

  /// Which refusal, when [startAction] is one: what is not ready, or the task an old name
  /// belonged to. Empty otherwise.
  final String startDetail;

  /// Whether a restart of its machine took it down and starting it brings it back whole: a `RESUME`
  /// that says why, or a `NEEDS_VAULT` that does, because its tokens wait in a locked vault
  /// (measured on Porelo 200). Before Porelo brought such tasks back, neither carried a reason.
  bool get takenDownByARestart =>
      !running &&
      (startAction == StartAction.resume || startAction == StartAction.needsVault) &&
      startDetail.isNotEmpty;

  /// What it is doing that takes minutes and shows nowhere else, such as `building`. Free text.
  final String phase;

  /// Which of its project's repositories it works in. **Empty is the project's own**:
  /// a container created before Porelo said so, never an unknown one.
  final String repository;

  /// The authorizations its credentials use, by entry: who granted each, and when. Never a token.
  final Map<String, Authorization> grants;

  /// The credentials it holds, the project's and those its start added: a vault entry's name to
  /// the destination or provider it is for. Never a token. Empty from a machine that does not say.
  final Map<String, String> credentials;

  /// What to say about this task's own work at the gate.
  ///
  /// Three answers, not two. **An `online` task's push passes through its gate to the forge, and
  /// nothing is ever reviewed**, so *"nothing of its own is waiting"* would imply that something
  /// could be.
  String get atTheGate => hasWorkWaiting
      ? 'its own work is waiting for review'
      : securityClass == 'online'
      ? 'nothing is reviewed in an online project'
      : 'nothing of its own is waiting';

  /// When the current state began, or null when the runtime could not say.
  DateTime? get startedAt => since.isEmpty ? null : DateTime.tryParse(since);

  /// Constructor taking every field.
  const Task({
    required this.name,
    this.label = '',
    required this.project,
    required this.securityClass,
    required this.state,
    required this.running,
    required this.helpers,
    this.agent = '',
    this.provider = '',
    this.mode = const Mode(''),
    this.prompt = '',
    this.branch = '',
    this.since = '',
    this.activity = const Activity(''),
    this.waitingFor = '',
    this.clearance = '',
    this.waiting = 0,
    this.task = '',
    this.startAction = const StartAction(''),
    this.startDetail = '',
    this.phase = '',
    this.repository = '',
    this.credentials = const <String, String>{},
    this.grants = const <String, Authorization>{},
    this.agentEnded,
    this.run,
    this.handInLimit,
    this.files,
    this.builds,
    this.buildReader,
    this.buildProblem,
  });

  /// How its agent ended, or null while it has not or the machine does not say.
  final AgentEnded? agentEnded;

  /// The container this task is, which tells its hand-in record from that of a later task with the
  /// same name. Null from a machine that does not say.
  final String? run;

  /// The bytes one file handed to this task may have. Null from a machine without hand-in, which
  /// is no limit of zero.
  final int? handInLimit;

  /// What the task has been handed, oldest first. **Null is not empty**: a machine without hand-in
  /// cannot say, and a person must not read that as *nothing was handed in*.
  final List<HandedFile>? files;

  /// The builds of what this task pushed, newest first. **Null is not empty**: a machine without
  /// them cannot say, which is not *nothing was built*.
  final List<Build>? builds;

  /// The forge whose builds of this task's pushes are followed, `""` when none are; null from a
  /// machine that cannot say.
  final String? buildReader;

  /// Why the named reader does not follow them, `""` while it does; null from a machine that cannot
  /// say.
  final String? buildProblem;

  /// Reads one from a reply.
  factory Task.from(Map<String, dynamic> map) => Task(
    name: _string(map, 'name'),
    label: _string(map, 'label'),
    project: _string(map, 'project'),
    securityClass: _string(map, 'securityClass'),
    state: _string(map, 'state'),
    running: map['running'] == true,
    helpers: _int(map, 'helpers'),
    // A task started before these fields existed answers empty for all of them. That is an
    // absence to render, not an error.
    agent: _string(map, 'agent'),
    provider: _string(map, 'provider'),
    mode: Mode(_string(map, 'mode')),
    prompt: _string(map, 'prompt'),
    branch: _string(map, 'branch'),
    since: _string(map, 'since'),
    activity: Activity(_string(map, 'activity')),
    waitingFor: _string(map, 'waitingFor'),
    clearance: _string(map, 'clearance'),
    waiting: _int(map, 'waiting'),
    task: _string(map, 'task'),
    startAction: StartAction(_string(map, 'startAction')),
    startDetail: _string(map, 'startDetail'),
    phase: _string(map, 'phase'),
    repository: _string(map, 'repository'),
    credentials: _stringMap(map, 'credentials'),
    grants: Authorization.allIn(map, 'grants'),
    agentEnded: map['agentEnded'] is Map<String, dynamic>
        ? AgentEnded.from(map['agentEnded'] as Map<String, dynamic>)
        : null,
    run: map['run'] is String ? map['run'] as String : null,
    handInLimit: map['handInLimit'] is num ? (map['handInLimit'] as num).toInt() : null,
    files: map['files'] is List
        ? (map['files'] as List).whereType<Map<String, dynamic>>().map(HandedFile.from).toList()
        : null,
    builds: map['builds'] is List
        ? (map['builds'] as List).whereType<Map<String, dynamic>>().map(Build.from).toList()
        : null,
    buildReader: map['buildReader'] is String ? map['buildReader'] as String : null,
    buildProblem: map['buildProblem'] is String ? map['buildProblem'] as String : null,
  );
}

/// The build of one commit a task pushed, as the machine follows it at the forge.
class Build {
  /// The commit that was pushed.
  final String commit;

  /// `queued`, `running`, `success`, `failure`, `cancelled` or `unknown`; a string, so a value added
  /// later renders rather than throws.
  final String verdict;

  /// Every job the forge reported, once the verdict is `failure` or final; empty before.
  final List<BuildJob> jobs;

  /// When the verdict last changed, as the machine wrote it.
  final String since;

  /// Why it is `unknown`, or what more the forge said; empty otherwise.
  final String detail;

  /// Constructor taking every field.
  const Build({
    required this.commit,
    required this.verdict,
    this.jobs = const <BuildJob>[],
    this.since = '',
    this.detail = '',
  });

  /// Reads one from a reply.
  factory Build.from(Map<String, dynamic> map) => Build(
    commit: _string(map, 'commit'),
    verdict: _string(map, 'verdict'),
    jobs: _list(map, 'jobs').map(BuildJob.from).toList(),
    since: _string(map, 'since'),
    detail: _string(map, 'detail'),
  );

  /// The commit as people read it: its first twelve characters.
  String get short => commit.length > 12 ? commit.substring(0, 12) : commit;

  /// Whether the forge is still working on it, so no job is listed yet.
  bool get underway => verdict == 'queued' || verdict == 'running';
}

/// One job of a build, as the forge names it.
class BuildJob {
  /// Workflow and job, as the forge spells them.
  final String name;

  /// What became of it, or its state while it runs, lower case as the forge says it.
  final String result;

  /// Its log's name in `/porelo/files`, or empty when none of it was delivered.
  final String log;

  /// Constructor taking every field.
  const BuildJob({required this.name, required this.result, this.log = ''});

  /// Reads one from a reply.
  factory BuildJob.from(Map<String, dynamic> map) =>
      BuildJob(name: _string(map, 'name'), result: _string(map, 'result'), log: _string(map, 'log'));
}

/// One file handed to a running task, as the machine's record holds it.
class HandedFile {
  /// The value [by] has for what Porelo hands in itself, such as a build's verdict and its log.
  static const porelo = 'porelo';

  /// As it appears in the task, under `/porelo/files`.
  final String name;

  /// Its size.
  final int bytes;

  /// Of its content, lower-case hex.
  final String sha256;

  /// When it was complete in the task, as the machine wrote it.
  final String at;

  /// The account that handed it in, or [porelo].
  final String by;

  /// The task's run it went to.
  final String run;

  /// Constructor taking every field.
  const HandedFile({
    required this.name,
    required this.bytes,
    required this.sha256,
    this.at = '',
    this.by = '',
    this.run = '',
  });

  /// Reads one from a reply.
  factory HandedFile.from(Map<String, dynamic> map) => HandedFile(
    name: _string(map, 'name'),
    bytes: _int(map, 'bytes'),
    sha256: _string(map, 'sha256'),
    at: _string(map, 'at'),
    by: _string(map, 'by'),
    run: _string(map, 'run'),
  );

  /// Whether Porelo handed it in rather than a person; compared, never guessed from the name.
  bool get byPorelo => by == porelo;

  /// Who handed it in, in words.
  String get from => byPorelo ? 'Porelo' : (by.isEmpty ? 'someone the machine does not name' : by);
}

/// One line of a task's hand-in record.
class HandInEvent {
  /// `given`, `replaced` or `taken back`; a string, so a value added later renders rather than throws.
  final String event;

  /// The file it was about.
  final HandedFile file;

  /// Constructor taking both.
  const HandInEvent({required this.event, required this.file});

  /// Reads one from a reply.
  factory HandInEvent.from(Map<String, dynamic> map) => HandInEvent(
    event: _string(map, 'event'),
    file: HandedFile.from(map['file'] is Map<String, dynamic> ? map['file'] as Map<String, dynamic> : const {}),
  );
}

/// What one part of a hand-in did: how far the machine is, and the file once it is complete.
class HandInPart {
  /// Bytes the machine holds for this file.
  final int received;

  /// Set once the last part made it complete and it is in the task.
  final HandedFile? file;

  /// Constructor taking both.
  const HandInPart({required this.received, this.file});

  /// Reads one from a reply.
  factory HandInPart.from(Map<String, dynamic> map) => HandInPart(
    received: _int(map, 'received'),
    file: map['file'] is Map<String, dynamic> ? HandedFile.from(map['file'] as Map<String, dynamic>) : null,
  );
}

/// What a task's terminal session shows: its last lines, and whether there is a session at all.
class Screen {
  /// Constructor taking both.
  const Screen({required this.lines, required this.live});

  /// Reads one from a reply.
  factory Screen.from(Map<String, dynamic> map) => Screen(lines: _strings(map, 'lines'), live: map['live'] == true);

  /// The last lines, oldest first.
  final List<String> lines;

  /// False where the task has no terminal session: unattended work, or a session that ended.
  final bool live;
}

/// How a task's agent ended, as its adapter read its last event.
class AgentEnded {
  /// Constructor taking every field.
  const AgentEnded({
    required this.at,
    required this.finished,
    this.error = '',
    this.source = '',
    this.status,
    this.unpushed = 0,
  });

  /// Reads one from a reply.
  factory AgentEnded.from(Map<String, dynamic> map) => AgentEnded(
    at: _string(map, 'at'),
    finished: map['finished'] == true,
    error: _string(map, 'error'),
    source: _string(map, 'source'),
    status: map['status'] is int ? map['status'] as int : null,
    unpushed: _int(map, 'unpushed'),
  );

  /// When the log's last line was written.
  final String at;

  /// Whether the agent answered its prompt to the end; false where the run stopped before that.
  final bool finished;

  /// What went wrong, as the agent or the provider gave it; empty where it finished.
  final String error;

  /// Whose the error is: `provider` or `agent`.
  final String source;

  /// The provider's HTTP status, where the provider refused.
  final int? status;

  /// How many changed files never reached the gate.
  final int unpushed;

  /// Whether a person has to look: it stopped before its end, or left work that never reached the
  /// gate.
  bool get needsSomebody => !finished || unpushed > 0;

  /// Whose refusal it was, named so the person knows where to look: the provider's account, its
  /// key or its limits, or the agent itself.
  String get whose {
    if (source != 'provider') return 'The agent ended with an error';
    return switch (status) {
      402 => 'The provider refused it: no credits left (402)',
      401 => 'The provider refused its key (401)',
      403 => 'The provider refused it (403): the key may not do this, or a limit was reached',
      429 => 'The provider refused it: too many requests, or a limit reached (429)',
      null => 'The provider refused it',
      final other => 'The provider refused it ($other)',
    };
  }

  /// In words, for a tile and for *Needs you*.
  String get words {
    final files = unpushed == 1
        ? '1 changed file never reached the gate'
        : '$unpushed changed files never reached the gate';
    if (finished) return unpushed > 0 ? 'The agent finished, but $files.' : 'The agent finished.';
    final said = error.trim().isEmpty ? '' : ': ${error.trim()}';
    return '$whose$said${unpushed > 0 ? '. $files' : ''}';
  }
}

/// An agent binary installed on the machine.
class Agent {
  /// Name the binary calls itself by, which is what starting a task takes.
  final String name;

  /// Human-readable name.
  final String label;

  /// The command it runs inside the container.
  final String binary;

  /// The build this agent pins, from `install.version` in its own manifest.
  ///
  /// **Not what the binary says about itself** — nothing executes an agent to ask. The IDL said
  /// otherwise once, which is how this was recorded as a gap when it was the answer.
  final String version;

  /// Where the binary was found.
  final String from;

  /// Hosts this agent needs, on top of the project's own.
  final List<String> allowedDomains;

  /// Hosts this agent declares and is **deliberately not given**.
  ///
  /// A decision, not an omission — and a dropped packet cannot tell the two apart, which is why
  /// it is worth saying out loud wherever the allowed list is shown.
  final List<String> refusedDomains;

  /// What this agent fetches when it is installed into an image.
  ///
  /// Empty is a normal answer: an agent that writes its tool into the image fetches nothing, so
  /// it has a pinned version and no digest at all.
  final List<InstallArtifact> artifacts;

  /// The identity this agent's commits carry, from its own manifest.
  ///
  /// **This is what tells somebody looking at a commit whether an agent or a person wrote it**,
  /// and it is what the pre-push guard on an operator's own checkout matches on. Until it was on
  /// the wire there was nowhere to look that up.
  ///
  /// The field is `commitsAs`, not `gitIdentity` — the second is what an agent's manifest calls
  /// it internally, and reading that name here would have found nothing and drawn a blank.
  final GitIdentity commitsAs;

  /// Whether the agent declares a login of its own, run on the machine by `porelo vault login`.
  final bool canLogIn;

  /// What the agent is started with to log in, inside the login's container. Said, never run here.
  final List<String> loginArguments;

  /// Where the agent documents its login, or empty.
  final String loginDocumentation;

  /// What to run on the machine to log in with it, as arguments, named by the machine; empty when it
  /// cannot log in, and from a Porelo older than the field.
  final List<String> loginCommand;

  /// Constructor taking every field.
  const Agent({
    this.canLogIn = false,
    this.loginArguments = const <String>[],
    this.loginDocumentation = '',
    this.loginCommand = const <String>[],
    required this.name,
    required this.label,
    required this.binary,
    required this.version,
    required this.from,
    required this.allowedDomains,
    this.refusedDomains = const <String>[],
    this.artifacts = const <InstallArtifact>[],
    this.commitsAs = const GitIdentity(name: '', email: ''),
  });

  /// Reads one from a reply.
  factory Agent.from(Map<String, dynamic> map) => Agent(
    name: _string(map, 'name'),
    label: _string(map, 'label'),
    binary: _string(map, 'binary'),
    version: _string(map, 'version'),
    from: _string(map, 'from'),
    allowedDomains: _strings(map, 'allowedDomains'),
    refusedDomains: _strings(map, 'refusedDomains'),
    artifacts: _list(map, 'artifacts').map(InstallArtifact.from).toList(),
    commitsAs: map['commitsAs'] is Map<String, dynamic>
        ? GitIdentity.from(map['commitsAs']! as Map<String, dynamic>)
        : const GitIdentity(name: '', email: ''),
    canLogIn: map['canLogIn'] == true,
    loginArguments: _strings(map, 'loginArguments'),
    loginDocumentation: _string(map, 'loginDocumentation'),
    loginCommand: _strings(map, 'loginCommand'),
  );
}

/// Who an agent's commits are attributed to.
class GitIdentity {
  /// Author name on its commits.
  final String name;

  /// Author address on its commits.
  final String email;

  /// Constructor taking both.
  const GitIdentity({required this.name, required this.email});

  /// Reads one from a reply.
  factory GitIdentity.from(Map<String, dynamic> map) =>
      GitIdentity(name: _string(map, 'name'), email: _string(map, 'email'));

  /// Whether anything was recorded. False for an agent installed by a Porelo older than the field.
  bool get recorded => name.isNotEmpty || email.isNotEmpty;

  /// How it reads on a commit, which is the form somebody is comparing against.
  String get words => email.isEmpty ? name : '$name <$email>';
}

/// One file an agent fetches when it is installed.
///
/// **There are two states and not three.** Either it carries a `sha256`, or it is `unverified`
/// with a stated `reason` — the daemon's own constructor refuses to build one with neither, so
/// nothing here has to render a blank digest with no explanation.
class InstallArtifact {
  /// Where it is fetched from.
  final String url;

  /// Its digest, lower case and 64 characters, or empty when [unverified].
  final String sha256;

  /// Where it lands in the image, or empty.
  final String target;

  /// Whether it is knowingly fetched without a digest.
  final bool unverified;

  /// Why it is unverified. **Never empty when [unverified]**, by the daemon's own rule.
  final String reason;

  /// Constructor taking every field.
  const InstallArtifact({
    required this.url,
    required this.sha256,
    required this.target,
    required this.unverified,
    required this.reason,
  });

  /// Reads one from a reply.
  factory InstallArtifact.from(Map<String, dynamic> map) => InstallArtifact(
    url: _string(map, 'url'),
    sha256: _string(map, 'sha256'),
    target: _string(map, 'target'),
    unverified: map['unverified'] == true,
    reason: _string(map, 'reason'),
  );
}

/// An installed agent binary that is never started, because another copy wins.
///
/// **A list rather than a flag on [Agent].** A shadowed binary is never executed, so it has no
/// `Agent` entry to mark — it is resolved away before anything is listed. The rule is that
/// locations are searched most specific first and the first filename wins.
class ShadowedAgent {
  /// The binary that does not run.
  final String path;

  /// The one that runs instead. Named rather than implied: *"not in use"* on its own leaves
  /// somebody asking where to look.
  final String usedInstead;

  /// Constructor taking both paths.
  const ShadowedAgent({required this.path, required this.usedInstead});

  /// Reads one from a reply.
  factory ShadowedAgent.from(Map<String, dynamic> map) =>
      ShadowedAgent(path: _string(map, 'path'), usedInstead: _string(map, 'usedInstead'));
}

/// One entry in the vault. Never its value.
class Credential {
  /// What it is called.
  final String name;

  /// What kind it is, or empty.
  final String type;

  /// Length of the stored value, so an interface can show that something is there.
  final int characters;

  /// What goes with the secret and is not secret, by name: a client id, a token URL. Shown whole.
  final Map<String, String> settings;

  /// Who granted the authorization it names, and when; null when none is granted, or for an entry
  /// that is not one a person grants.
  final Authorization? grant;

  /// Constructor taking every field.
  const Credential({
    required this.name,
    required this.type,
    required this.characters,
    this.settings = const <String, String>{},
    this.grant,
  });

  /// How a vault entry's name appears inside a task, after `PORELO_TOKEN_` and `PORELO_URL_`:
  /// upper-cased, anything but a letter or digit as `_`. Measured: `f56-api` is `PORELO_TOKEN_F56_API`.
  static String variableOf(String entry) => entry.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '_');

  /// Whether it names a service a person grants an authorization for, once, in a browser.
  bool get isGranted => type == 'oauth-device' || type == 'oauth-code';

  /// Reads one from a reply.
  factory Credential.from(Map<String, dynamic> map) => Credential(
    name: _string(map, 'name'),
    type: _string(map, 'type'),
    characters: _int(map, 'characters'),
    settings: _stringMap(map, 'settings'),
    grant: Authorization.of(map['grant']),
  );
}

/// The project every machine has, which Porelo keeps itself and nobody configures: work on a
/// repository without writing a project first goes there.
const String defaultProject = 'default';

/// A repository worked on in [defaultProject]: added by its address, and worked on with Porelo's own
/// fixed settings until a followed project names it.
class DefaultRepository {
  /// What its tasks name it by.
  final String name;

  /// Where approved work goes: for a [source] of `CHECKOUT` the checkout's path, else the address.
  final String upstream;

  /// Where its history comes from and its approved work goes: `CHECKOUT` or `REMOTE`; null from a
  /// machine older than one source per repository, which is not the same as either.
  final String? source;

  /// The checkout's `origin` where it was added from one, shown only and never reached; else the
  /// address. Null from an older machine.
  final String? remote;

  /// Where it is checked out on the machine, where it was added from one, or empty.
  final String checkout;

  /// The followed project that names the same repository, or empty. Where it is set, that project's
  /// tasks are the ones to start, and the repository can be taken out of `default`.
  final String claimedBy;

  /// Constructor taking every field.
  const DefaultRepository({
    required this.name,
    required this.upstream,
    required this.checkout,
    required this.claimedBy,
    this.source,
    this.remote,
  });

  /// Where its work comes from and goes, in one line; the address alone from an older machine.
  String get comesFromAndGoes => switch (source) {
    'CHECKOUT' =>
      'From the checkout $upstream, and back into it as porelo/<task>; '
          '${(remote ?? '').isEmpty ? 'it has no remote' : 'its remote $remote is yours to pull and push'}',
    'REMOTE' => 'From ${(remote ?? '').isEmpty ? upstream : remote}, and back there',
    _ => upstream,
  };

  /// Reads one from a reply.
  factory DefaultRepository.from(Map<String, dynamic> map) => DefaultRepository(
    name: _string(map, 'name'),
    upstream: _string(map, 'upstream'),
    checkout: _string(map, 'checkout'),
    claimedBy: _string(map, 'claimedBy'),
    source: map['source'] is String ? map['source'] as String : null,
    remote: map['remote'] is String ? map['remote'] as String : null,
  );
}

/// What bringing a task up to its source did (`RefreshTask`).
class TaskRefreshed {
  /// `MOVED`, `UNCHANGED`, `NOT_GATED` or `FAILED`; another is said as it comes.
  final String outcome;

  /// Each branch that moved, and the commit it names now.
  final Map<String, String> moved;

  /// Why, for `FAILED`.
  final String detail;

  /// Whether its agent heard of it.
  final bool told;

  /// Constructor taking every field.
  const TaskRefreshed({
    required this.outcome,
    this.moved = const <String, String>{},
    this.detail = '',
    this.told = false,
  });

  /// Reads one from a reply.
  factory TaskRefreshed.from(Map<String, dynamic> map) => TaskRefreshed(
    outcome: _string(map, 'outcome'),
    moved: <String, String>{
      for (final each in (map['moved'] is Map ? map['moved'] as Map : const <String, dynamic>{}).entries)
        '${each.key}': '${each.value}',
    },
    detail: _string(map, 'detail'),
    told: map['told'] == true,
  );

  /// What it did, for [task], in one line.
  String wordsFor(String task) {
    String short(String commit) => commit.length > 12 ? commit.substring(0, 12) : commit;
    return switch (outcome) {
      'MOVED' =>
        '${[for (final each in moved.entries) '${each.key} moved to ${short(each.value)}'].join(', ')}; '
            '${told ? 'its agent was told, and git fetch porelo brings it' : 'its agent was not told - git fetch porelo in $task brings it'}',
      'UNCHANGED' => '$task is up to date with its source.',
      // Only a task with no gate at all answers this: one started without a gate, or an offline one.
      // An online task has a gate too, and answers MOVED or UNCHANGED.
      'NOT_GATED' =>
        '$task has no gate, so there is nothing here to bring up to its source: '
            'it was started without one, or it is offline.',
      'FAILED' => '$task could not be brought up to its source: $detail',
      _ => '$task: ${outcome.toLowerCase().replaceAll('_', ' ')}${detail.isEmpty ? '' : ': $detail'}',
    };
  }
}

/// A machine's deploy key for one repository of a project: **only the public half**; the secret half
/// stays in the machine's vault.
class MachineDeployKey {
  /// Its vault entry on the machine.
  final String entry;

  /// The repository it is for.
  final String repository;

  /// The upstream it is declared for.
  final String upstream;

  /// `ssh-ed25519 AAAA… porelo@<host>`: what the forge is given.
  final String publicKey;

  /// `SHA256:…`.
  final String fingerprint;

  /// What the forge should call it: `porelo <machine> <project>/<repository>`.
  final String title;

  /// Whether the forge is to give it write access: false for the project's own repository, which a
  /// machine reads and never writes; true for a work repository.
  final bool writeAccess;

  /// Whether it was made just now, rather than the one the machine had.
  final bool made;

  /// Constructor taking every field.
  const MachineDeployKey({
    required this.entry,
    required this.repository,
    required this.upstream,
    required this.publicKey,
    required this.fingerprint,
    required this.title,
    required this.writeAccess,
    required this.made,
  });

  /// Reads one from a reply.
  factory MachineDeployKey.from(Map<String, dynamic> map) => MachineDeployKey(
    entry: _string(map, 'entry'),
    repository: _string(map, 'repository'),
    upstream: _string(map, 'upstream'),
    publicKey: _string(map, 'publicKey'),
    fingerprint: _string(map, 'fingerprint'),
    title: _string(map, 'title'),
    writeAccess: map['writeAccess'] == true,
    made: map['made'] == true,
  );
}

/// A machine's message key: what a project's `machine-signers` names it by.
class MachineKey {
  /// `porelo@<host>`.
  final String principal;

  /// `ssh-ed25519 AAAA…`.
  final String key;

  /// The `machine-signers` line: principal and key.
  final String line;

  /// `SHA256:…`.
  final String fingerprint;

  /// Constructor taking every field.
  const MachineKey({required this.principal, required this.key, required this.line, required this.fingerprint});

  /// Reads one from a reply.
  factory MachineKey.from(Map<String, dynamic> map) => MachineKey(
    principal: _string(map, 'principal'),
    key: _string(map, 'key'),
    line: _string(map, 'line'),
    fingerprint: _string(map, 'fingerprint'),
  );
}

/// The keys a project file may hold in each section, as one machine's Porelo knows them.
class ProjectFileSchema {
  /// Section to its keys: `""` is the top level; `mail.peers.<peer>` and `repositories.<repository>`
  /// stand for each named one.
  final Map<String, List<String>> sections;

  /// What Porelo does not check: the project's own names, and each transport's settings.
  final List<String> open;

  /// Every key described: what it means, its type, its values and default, and whether it is
  /// required. Empty from a Porelo that does not describe them.
  final List<ProjectFileKey> keys;

  /// Constructor taking every field.
  const ProjectFileSchema({required this.sections, required this.open, this.keys = const <ProjectFileKey>[]});

  /// Reads one from a reply.
  factory ProjectFileSchema.from(Map<String, dynamic> map) => ProjectFileSchema(
    keys: <ProjectFileKey>[
      if (map['keys'] case final List<dynamic> keys)
        for (final each in keys)
          if (each is Map<String, dynamic>) ProjectFileKey.from(each),
    ],
    sections: <String, List<String>>{
      if (map['sections'] case final Map<String, dynamic> sections)
        for (final entry in sections.entries)
          entry.key: <String>[
            if (entry.value case final List<dynamic> keys)
              for (final each in keys)
                if (each is String) each,
          ],
    },
    open: _strings(map, 'open'),
  );
}

/// One key a project file may hold, as the machine's Porelo describes it.
class ProjectFileKey {
  /// Where it sits: `""` for the top level, `mail.peers.<peer>` for each named one.
  final String section;

  /// The key's own name within [section].
  final String name;

  /// What it means, in one sentence: Porelo's words, never written a second time here.
  final String describe;

  /// `string`, `boolean`, `integer`, `list` or `map`.
  final String type;

  /// The values it takes where they are a fixed set; empty otherwise.
  final List<String> values;

  /// What it is when the file does not say, spelt as the file would; empty for nothing.
  final String defaultValue;

  /// Whether a project file without it is refused.
  final bool required;

  /// Constructor taking every field.
  const ProjectFileKey({
    required this.section,
    required this.name,
    required this.describe,
    required this.type,
    required this.values,
    required this.defaultValue,
    required this.required,
  });

  /// Reads one from a reply.
  factory ProjectFileKey.from(Map<String, dynamic> map) => ProjectFileKey(
    section: _string(map, 'section'),
    name: _string(map, 'name'),
    describe: _string(map, 'describe'),
    type: _string(map, 'type'),
    values: _strings(map, 'values'),
    defaultValue: _string(map, 'default'),
    required: map['required'] == true,
  );
}

/// What one machine says of a draft `project.yml`, before a person commits it.
class ProjectFileCheck {
  /// What Porelo refuses anywhere: **blocks the commit**.
  final List<String> refused;

  /// What this machine's follow would refuse: an egress set it does not have.
  final List<String> refusedHere;

  /// What only this machine lacks, or a key a later Porelo may know: warns, never blocks.
  final List<String> warnings;

  /// Constructor taking every list.
  const ProjectFileCheck({required this.refused, required this.refusedHere, required this.warnings});

  /// Reads one from a reply.
  factory ProjectFileCheck.from(Map<String, dynamic> map) => ProjectFileCheck(
    refused: _strings(map, 'refused'),
    refusedHere: _strings(map, 'refusedHere'),
    warnings: _strings(map, 'warnings'),
  );
}

/// A project's conversation, on a transport that keeps one: its room, for Matrix.
class ProjectMessages {
  /// The transport, as a peer's address names it: `matrix`.
  final String transport;

  /// What the transport calls it (a room's id), or empty before it was set up on this machine.
  final String conversation;

  /// What the project's messages reach through it, as the transport says: its homeserver.
  final List<String> reaches;

  /// Whether this machine can carry the project's messages now.
  final bool ready;

  /// Why not, in the machine's words, or empty.
  final String detail;

  /// Whether it must stay on this machine's loopback: an `offline` project.
  final bool loopbackOnly;

  /// Why its messages wait now, in the machine's words (the vault locked), or empty while they move.
  /// Empty from a daemon older than the field, which says nothing either way.
  final String waits;

  /// Constructor taking every field.
  const ProjectMessages({
    required this.transport,
    required this.conversation,
    required this.reaches,
    required this.ready,
    required this.detail,
    required this.loopbackOnly,
    this.waits = '',
  });

  /// Reads one from a reply, or null where there is none.
  static ProjectMessages? of(Object? value) => value is Map<String, dynamic>
      ? ProjectMessages(
          transport: _string(value, 'transport'),
          conversation: _string(value, 'conversation'),
          reaches: _strings(value, 'reaches'),
          ready: value['ready'] == true,
          detail: _string(value, 'detail'),
          loopbackOnly: value['loopbackOnly'] == true,
          waits: _string(value, 'waits'),
        )
      : null;
}

/// Someone who has joined a project's conversation.
class MessageMember {
  /// The name the join was given.
  final String person;

  /// The account the transport made for them.
  final String user;

  /// Constructor taking both.
  const MessageMember({required this.person, required this.user});

  /// Reads one from a reply.
  factory MessageMember.from(Map<String, dynamic> map) =>
      MessageMember(person: _string(map, 'person'), user: _string(map, 'user'));
}

/// What joining a project's conversation answered: **once**, the login in it and nowhere else.
class MessagesJoined {
  /// The transport it is on.
  final String transport;

  /// The login as the transport gave it, passed through: for Matrix `homeserver`, `user`, `room`,
  /// `password`, and `loopback` ("true") with `port` where the homeserver is the machine's loopback.
  final Map<String, String> login;

  /// What a terminal prints.
  final String shown;

  /// Constructor taking every field.
  const MessagesJoined({required this.transport, required this.login, required this.shown});

  /// Reads one from a reply.
  factory MessagesJoined.from(Map<String, dynamic> map) => MessagesJoined(
    transport: _string(map, 'transport'),
    login: _stringMap(map, 'login'),
    shown: _string(map, 'shown'),
  );

  /// Whether the homeserver is the machine's own loopback, so a client elsewhere needs [port] forwarded.
  bool get loopback => login['loopback'] == 'true';

  /// The loopback port to forward, or null.
  int? get port => int.tryParse(login['port'] ?? '');
}

/// A credential somebody has to authorize before work can use it, as `Authorizations` streams it.
class AuthorizationNeeded {
  /// The vault entry naming the service; `Authorize` takes it as `name`.
  final String credential;

  /// The task that needed it, or empty.
  final String task;

  /// That task's project, or empty.
  final String project;

  /// `never` (nobody granted it), `ended` (the grant was revoked or expired at the service), or
  /// `granted` (a grant landed, and the question is gone).
  final String state;

  /// When it was raised, or for `granted` when the grant was seen.
  final String at;

  /// Constructor taking every field.
  const AuthorizationNeeded({
    required this.credential,
    required this.task,
    required this.project,
    required this.state,
    required this.at,
  });

  /// Reads one from a reply.
  factory AuthorizationNeeded.from(Map<String, dynamic> map) => AuthorizationNeeded(
    credential: _string(map, 'credential'),
    task: _string(map, 'task'),
    project: _string(map, 'project'),
    state: _string(map, 'state'),
    at: _string(map, 'at'),
  );
}

/// An authorization a person granted once: who, and when. **Never the grant itself**, which stays
/// hidden in the machine's vault.
class Authorization {
  /// Who granted it, as the machine recorded them.
  final String grantedBy;

  /// When, RFC 3339.
  final String grantedAt;

  /// Constructor taking both.
  const Authorization({required this.grantedBy, required this.grantedAt});

  /// Reads one from a reply, or null where there is none.
  static Authorization? of(Object? value) => value is Map<String, dynamic>
      ? Authorization(grantedBy: _string(value, 'grantedBy'), grantedAt: _string(value, 'grantedAt'))
      : null;

  /// Grants by the name of the entry they are for.
  static Map<String, Authorization> allIn(Map<String, dynamic> map, String key) => <String, Authorization>{
    if (map[key] case final Map<String, dynamic> each)
      for (final entry in each.entries) entry.key: ?Authorization.of(entry.value),
  };
}

/// One reply of `Authorize`: where granting an authorization stands.
///
/// The first is `needed`, with the link to open, **whole, as it came**; the last is `granted`,
/// `refused`, `expired` or `failed`. Nothing here is a secret: the grant stays in the machine's
/// vault, and no task holds it.
class AuthorizeProgress {
  /// `needed`, then `granted`, `refused`, `expired` or `failed`.
  final String state;

  /// The page a person opens to decide, or empty after the first reply.
  final String link;

  /// For a device code, what to type if the link does not carry it; empty for a redirect.
  final String code;

  /// For a redirect, the loopback port on the machine the answer comes back to; 0 for a device code.
  final int port;

  /// Seconds until the question expires, or 0 when the machine did not say.
  final int expiresIn;

  /// Why it failed, in the machine's words, or empty.
  final String detail;

  /// Constructor taking every field.
  const AuthorizeProgress({
    required this.state,
    this.link = '',
    this.code = '',
    this.port = 0,
    this.expiresIn = 0,
    this.detail = '',
  });

  /// Reads one from a reply.
  factory AuthorizeProgress.from(Map<String, dynamic> map) => AuthorizeProgress(
    state: _string(map, 'state'),
    link: _string(map, 'link'),
    code: _string(map, 'code'),
    port: _int(map, 'port'),
    expiresIn: _int(map, 'expiresIn'),
    detail: _string(map, 'detail'),
  );

  /// Whether this is the last reply: the question is settled one way or the other.
  bool get settled => state != 'needed';
}

/// What locking the store did.
class Locked {
  /// Whether the kernel keyring is available at all.
  final bool keyring;

  /// Whether a passphrase was cached before this. `false` means the store was already shut.
  final bool wasCached;

  /// How many running tasks still hold what they read when they started.
  ///
  /// **Said in the same breath as "locked", never in a detail underneath.** A running task's
  /// credential proxy read the secret at start and holds it in its own memory, where locking
  /// cannot reach. Reporting the store shut without this claims more than happened.
  final int holding;

  /// Constructor taking every field.
  const Locked({required this.keyring, required this.wasCached, required this.holding});

  /// Reads one from a reply.
  factory Locked.from(Map<String, dynamic> map) =>
      Locked(keyring: map['keyring'] == true, wasCached: map['wasCached'] == true, holding: _int(map, 'holding'));

  /// What to say about it, in one sentence.
  String get words {
    final shut = wasCached ? 'The vault is shut.' : 'The vault was already shut.';
    if (holding == 0) return shut;
    final work = holding == 1 ? 'task' : 'tasks';
    return '$shut $holding running $work still ${holding == 1 ? 'holds' : 'hold'} what '
        '${holding == 1 ? 'it' : 'they'} read at start — locking cannot reach that.';
  }
}

/// How a device keeps the share that opens a vault, as the device declared it.
///
/// **Proposed for Porelo's keyslots, not on `Tasks1` yet.** A closed set on the node, which refuses an
/// unknown value rather than recording it; a string here by the rule every other value follows, so
/// one added later renders rather than throws.
class KeyslotStorage {
  /// Constructor taking the name as the contract spells it.
  const KeyslotStorage(this.name);

  /// The value as it came.
  final String name;

  /// A store that unlocks at login, such as a Secret Service keyring or DPAPI: **anything running as
  /// this user can ask for the share.** What Linux and Windows offer.
  static const userScoped = KeyslotStorage('USER_SCOPED');

  /// A store only this application can read: iOS, Android, a signed macOS application.
  static const applicationScoped = KeyslotStorage('APPLICATION_SCOPED');

  /// Derived at unlock from a FIDO2 token's `hmac-secret`, so releasing it needs a touch.
  static const fido2 = KeyslotStorage('FIDO2');

  /// Derived at unlock from a TPM2 object behind a PIN.
  static const tpm2 = KeyslotStorage('TPM2');

  /// The values this build knows.
  static const known = <KeyslotStorage>[userScoped, applicationScoped, fido2, tpm2];

  /// Whether this build knows what it means.
  bool get recognized => known.contains(this);

  @override
  bool operator ==(Object other) => other is KeyslotStorage && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => name;
}

/// What a keyslot call answered. **Proposed for Porelo's keyslots, not on `Tasks1` yet.**
///
/// One set for the three calls, because they share most of it; each call answers only its own.
class KeyslotOutcome {
  /// Constructor taking the name as the contract spells it.
  const KeyslotOutcome(this.name);

  /// The value as it came.
  final String name;

  /// The device is a keyslot now.
  static const enrolled = KeyslotOutcome('ENROLLED');

  /// The share given opens a keyslot that already exists: this device was enrolled before.
  static const alreadyEnrolled = KeyslotOutcome('ALREADY_ENROLLED');

  /// The storage class is not one the node records.
  static const unknownStorage = KeyslotOutcome('UNKNOWN_STORAGE');

  /// The share is not 32 bytes of base64.
  static const badShare = KeyslotOutcome('BAD_SHARE');

  /// The vault is shut, so nothing can be wrapped or revoked.
  static const vaultLocked = KeyslotOutcome('VAULT_LOCKED');

  /// This vault predates keyslots.
  static const vaultWithoutKeyslots = KeyslotOutcome('VAULT_WITHOUT_KEYSLOTS');

  /// The keyslot is gone.
  static const revoked = KeyslotOutcome('REVOKED');

  /// No keyslot has that id.
  static const noSuchSlot = KeyslotOutcome('NO_SUCH_SLOT');

  /// Revoking it would leave nothing that opens the vault.
  static const lastWayIn = KeyslotOutcome('LAST_WAY_IN');

  /// The vault is open, until the time the reply names.
  static const unlocked = KeyslotOutcome('UNLOCKED');

  /// No keyslot opens with this share: the device was revoked, or never enrolled here.
  static const shareRejected = KeyslotOutcome('SHARE_REJECTED');

  /// Something went wrong that is none of the above; the detail says what.
  static const failed = KeyslotOutcome('FAILED');

  /// The values this build knows.
  static const known = <KeyslotOutcome>[
    enrolled,
    alreadyEnrolled,
    unknownStorage,
    badShare,
    vaultLocked,
    vaultWithoutKeyslots,
    revoked,
    noSuchSlot,
    lastWayIn,
    unlocked,
    shareRejected,
    failed,
  ];

  /// Whether this build knows what it means.
  bool get recognized => known.contains(this);

  @override
  bool operator ==(Object other) => other is KeyslotOutcome && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => name;
}

/// One credential allowed to open a vault: a device, or the recovery passphrase.
///
/// **Proposed for Porelo's keyslots, not on `Tasks1` yet.** Holds no secret: the node discarded the share at
/// enrollment, and nothing about it comes back.
class Keyslot {
  /// Assigned by the node, and kept by the device beside its share.
  final String id;

  /// What a person called the device. Shown, never an identifier.
  final String name;

  /// How the device keeps its share, as it declared it.
  final KeyslotStorage storage;

  /// When it was enrolled.
  final String enrolled;

  /// When it last opened the vault, or empty when it has not since it was enrolled.
  final String lastUsed;

  /// Whether this session was unlocked with it. **Knowable only after an unlock.**
  final bool self;

  /// Whether it is the recovery passphrase, keyslot 0, rather than a device.
  final bool recovery;

  /// Constructor taking every field.
  const Keyslot({
    required this.id,
    required this.name,
    required this.storage,
    required this.enrolled,
    required this.lastUsed,
    required this.self,
    required this.recovery,
  });

  /// Reads one from a reply.
  factory Keyslot.from(Map<String, dynamic> map) => Keyslot(
    id: _string(map, 'id'),
    name: _string(map, 'name'),
    storage: KeyslotStorage(_string(map, 'storage')),
    enrolled: _string(map, 'enrolled'),
    lastUsed: _string(map, 'lastUsed'),
    self: map['self'] == true,
    recovery: map['recovery'] == true,
  );
}

/// What enrolling a device did. **Proposed for Porelo's keyslots.**
class Enrolled {
  /// What happened.
  final KeyslotOutcome outcome;

  /// The keyslot, when there is one.
  final Keyslot? slot;

  /// Prose for a person. Never parsed, and never carrying the share.
  final String detail;

  /// Constructor taking every field.
  const Enrolled({required this.outcome, required this.slot, required this.detail});

  /// Reads one from a reply.
  factory Enrolled.from(Map<String, dynamic> map) => Enrolled(
    outcome: KeyslotOutcome(_string(map, 'outcome')),
    slot: map['slot'] is Map<String, dynamic> ? Keyslot.from(map['slot'] as Map<String, dynamic>) : null,
    detail: _string(map, 'detail'),
  );
}

/// What revoking a keyslot did. **Proposed for Porelo's keyslots.**
class Revoked {
  /// What happened.
  final KeyslotOutcome outcome;

  /// What can still open the vault afterwards, so a screen says it without asking again.
  final List<Keyslot> remaining;

  /// Prose for a person. Never parsed.
  final String detail;

  /// Constructor taking every field.
  const Revoked({required this.outcome, required this.remaining, required this.detail});

  /// Reads one from a reply.
  factory Revoked.from(Map<String, dynamic> map) => Revoked(
    outcome: KeyslotOutcome(_string(map, 'outcome')),
    remaining: _list(map, 'remaining').map(Keyslot.from).toList(),
    detail: _string(map, 'detail'),
  );
}

/// What unlocking with a share did. **Proposed for Porelo's keyslots.**
class UnlockedWithShare {
  /// What happened.
  final KeyslotOutcome outcome;

  /// Until when it stays open, or empty.
  final String until;

  /// The keyslot that opened it, when one did.
  final Keyslot? slot;

  /// Prose for a person. Never parsed, and never carrying the share.
  final String detail;

  /// Constructor taking every field.
  const UnlockedWithShare({required this.outcome, required this.until, required this.slot, required this.detail});

  /// Reads one from a reply.
  factory UnlockedWithShare.from(Map<String, dynamic> map) => UnlockedWithShare(
    outcome: KeyslotOutcome(_string(map, 'outcome')),
    until: _string(map, 'until'),
    slot: map['slot'] is Map<String, dynamic> ? Keyslot.from(map['slot'] as Map<String, dynamic>) : null,
    detail: _string(map, 'detail'),
  );
}

/// One project on the machine.
///
/// Assembled by the daemon from the gate mirrors, the tasks that exist and the project files task
/// starts have recorded — not stored, and not registered. A project appears the first time
/// somebody runs a task with it.
class Project {
  /// Project name, as its file declares it.
  final String name;

  /// offline, guarded or online. Empty when no task has recorded one.
  final String securityClass;

  /// Absolute path of its `project.yml` **on the daemon's machine**.
  ///
  /// **Not what a method takes**: every method that acts on a project takes its
  /// [name]. This says where the verified file is, and never offer a file picker for it — over a
  /// forwarded socket there is no filesystem on that machine to pick from.
  ///
  /// **Empty is a project the machine does not follow**, known only from tasks left behind: it is
  /// listed and never acted on, which is what [canBeActedOn] says.
  final String file;

  /// The gate's mirror for it. Empty when it has never used the gate.
  final String mirror;

  /// How many pushes are waiting for review in that mirror. The same number `Pending` returns.
  final int pending;

  /// How many of its tasks exist right now, running or stopped.
  final int tasks;

  /// How many of those are up.
  ///
  /// Given rather than inferred, and a project with none is the ordinary case — between tasks, or
  /// after one was stopped and can still be resumed, which keeps its workspace. **`Projects`
  /// lists every project, not only the busy ones**; filtering to a busy view is this end's job
  /// and must never be assumed of the other.
  final int running;

  /// Whether a task can start here without building an image first.
  ///
  /// One call on the daemon's side for the whole list, not one per project — `Projects` is asked
  /// again after every task start and every approval, so a subprocess per project would have made
  /// ordinary use of this interface expensive for reasons nothing on screen could explain.
  final bool prepared;

  /// What [prepared] cannot say: `ABSENT`, `READY`, `STALE` or `UNKNOWN`.
  ///
  /// **`STALE` is the state this field exists for.** An image is there and was built before the
  /// project file changed under it, so work would start in something the file no longer describes
  /// and nothing would mention it. A bool could only ever say whether something was there.
  ///
  /// **`UNKNOWN` is not stale.** It is an image that does not record what it was built from —
  /// built by an older Porelo, or belonging to a project whose file has moved. Nothing knows either
  /// way, and drawing it as stale sends somebody rebuilding for no reason, which is how a word
  /// stops being read.
  ///
  /// Only the base image and the image snippet decide it. Egress, limits and the upstream change
  /// what a task may *do* rather than what it is built *from*.
  ///
  /// Empty from a daemon older than the field, which is an absence to render rather than a fourth
  /// meaning to invent.
  final String preparedState;

  /// Whether work started here would run in something the project file no longer describes.
  bool get environmentIsStale => preparedState == 'STALE';

  /// What to say about the environment, or empty when there is nothing worth saying.
  ///
  /// **Nothing for `READY`, and nothing for a daemon that did not say.** A row that commented on
  /// every project would bury the one that matters.
  String get environmentWords => switch (preparedState) {
    'ABSENT' => 'no environment yet — the first task here builds one, which takes minutes',
    'STALE' =>
      'built before the project file changed: work would run in something the file '
          'no longer describes',
    'UNKNOWN' =>
      'nothing records what this image was built from, so whether it matches the '
          'project file cannot be said',
    _ => '',
  };

  /// How many commits its mirror is behind the upstream.
  ///
  /// **Meaningless unless [behindReason] is `MEASURED`.** Zero means "up to date" only then; the
  /// other reasons all report zero and mean something else entirely.
  final int behind;

  /// When [behind] was measured, RFC 3339. Empty when it never was.
  ///
  /// **Not optional to show.** A number with no age has to be drawn as though it were current,
  /// and the only thing worse than a stale answer is a stale answer that looks fresh. It is
  /// measured on the daemon's own timer, never on the listing path.
  final String behindMeasured;

  /// Why [behind] says what it says: `MEASURED`, `NEVER_CHECKED`, `NO_UPSTREAM`, `OFFLINE` or
  /// `FAILED`.
  ///
  /// A string rather than an enum, by the rule that already covers [Outcome]: a value added later
  /// must render rather than throw. **There is no `VAULT_LOCKED`** — the gate fetches with the
  /// machine's own git credentials and the vault is not in that path at all.
  final String behindReason;

  /// Prose for a person, only when [behindReason] is `FAILED`. Never parsed.
  final String behindDetail;

  /// The repositories work can start in, by name: the project's own first, in the order to offer
  /// them. **Empty is not one repository**: it means the daemon could not read the
  /// project file — or is older than repositories per project and says nothing — and a start then names none.
  final List<String> repositories;

  /// What the daemon says about each of [repositories], in the same order. A Porelo that answered
  /// names only fills in nothing but the name.
  final List<Repository> repositoryStates;

  /// Where this account has got following the project's repository, or null when it follows
  /// nothing here — the ordinary case, and never the same as followed with nothing known yet.
  final Followed? following;

  /// Whether the machine said anything about following at all. A Porelo that knows following answers
  /// `following` on every project, and an empty one for a project nothing follows; an older Porelo
  /// answers nothing, and its projects are acted on as they always were.
  final bool followingAnswered;

  /// What its `project.yml` names under `credentials:`: a vault entry's name to the destination
  /// or provider it is for. Every task of the project holds these, and a start cannot point one
  /// elsewhere.
  final Map<String, String> credentials;

  /// The project's conversation, where a peer is reached through a transport's own (`matrix:`);
  /// null for a project with none, or from a machine that does not say.
  final ProjectMessages? messages;

  /// Whether the machine said which credentials it names at all. False from one older than that,
  /// where an empty [credentials] means *not said*, not *none*.
  final bool credentialsAnswered;

  /// The repositories work starts in. A project that names others under `repositories:` is never
  /// worked in itself: its own repository holds its file, its planning and its issues, and a start
  /// there is refused. A project of one repository is that repository.
  List<String> get workRepositories {
    if (repositories.length < 2) return repositories;
    final own = ownRepository;
    return <String>[
      for (final each in repositories)
        if (each != own) each,
    ];
  }

  /// The project's own repository, or null where the machine names none.
  String? get ownRepository => repositoryStates.where((each) => each.own).firstOrNull?.name ?? repositories.firstOrNull;

  /// The repository [task] works in, as a start takes it: the project's own where the task says
  /// nothing, which is what saying nothing means — and so null where the machine names none.
  String? repositoryOf(Task task) => task.repository.isEmpty ? ownRepository : task.repository;

  /// Constructor taking every field.
  const Project({
    required this.name,
    required this.securityClass,
    required this.file,
    required this.mirror,
    required this.pending,
    required this.tasks,
    required this.running,
    this.prepared = false,
    this.preparedState = '',
    this.behind = 0,
    this.behindMeasured = '',
    this.behindReason = '',
    this.behindDetail = '',
    this.repositories = const <String>[],
    this.repositoryStates = const <Repository>[],
    this.following,
    this.followingAnswered = false,
    this.credentials = const <String, String>{},
    this.credentialsAnswered = false,
    this.messages,
  });

  /// Reads one from a reply.
  factory Project.from(Map<String, dynamic> map) => Project(
    name: _string(map, 'name'),
    securityClass: _string(map, 'securityClass'),
    file: _string(map, 'file'),
    mirror: _string(map, 'mirror'),
    pending: _int(map, 'pending'),
    tasks: _int(map, 'tasks'),
    running: _int(map, 'running'),
    prepared: map['prepared'] == true,
    preparedState: _string(map, 'preparedState'),
    behind: _int(map, 'behind'),
    behindMeasured: _string(map, 'behindMeasured'),
    behindReason: _string(map, 'behindReason'),
    behindDetail: _string(map, 'behindDetail'),
    repositories: <String>[for (final each in Repository.allIn(map)) each.name],
    repositoryStates: Repository.allIn(map),
    following: Followed.of(map['following']),
    followingAnswered: map.containsKey('following'),
    credentials: _stringMap(map, 'credentials'),
    credentialsAnswered: map.containsKey('credentials'),
    messages: ProjectMessages.of(map['messages']),
  );

  /// Whether this project is behind its upstream by an amount somebody can act on.
  ///
  /// False for every reason but `MEASURED`, because [behind] is zero in all of them and zero
  /// would otherwise read as *up to date*.
  bool get hasFallenBehind => behindReason == 'MEASURED' && behind > 0;

  /// What to say about how far behind it is, in one line.
  ///
  /// The age is part of the sentence rather than a detail underneath it: the number is only as
  /// good as when it was taken, and a reader who cannot see that has to assume it is current.
  String get behindWords => _behindWords(behindReason, behind, behindMeasured, behindDetail);

  /// Whether anything can be done to it beyond looking at it.
  ///
  /// Every method that acts on a project takes its **name**, and accepts only a project this
  /// machine follows. **A file is not enough**: a project left from before projects were followed
  /// still carries the path the old registry recorded, and the machine refuses every call about it.
  /// So where the machine says what it follows, only a followed one is acted on; one known only
  /// from what was left behind is listed and not acted on — a state to render, never an error.
  ///
  /// **`default` is the exception**: followed by nobody, and acted on by its name like
  /// any followed project — work starts there, and waits at its gate.
  bool get canBeActedOn => file.isNotEmpty && (!followingAnswered || following != null || name == defaultProject);
}

/// One host a project's work may reach, and what granted it.
class EgressHost {
  /// The host.
  final String host;

  /// What granted it: `agent <name>`, `provider <name>`, `set <name>`, `project` or `upstream`.
  ///
  /// **The first grant wins**, so a host in both a set and an agent's list is reported as the
  /// agent's — which is why the order it arrives in is meaningful and must not be sorted away.
  final String origin;

  /// Constructor taking the host and its origin.
  const EgressHost({required this.host, required this.origin});

  /// Reads one from a reply.
  factory EgressHost.from(Map<String, dynamic> map) =>
      EgressHost(host: _string(map, 'host'), origin: _string(map, 'origin'));
}

/// A curated set of destinations, installed on the machine.
class EgressSet {
  /// What a project writes in its `egress.sets`, and what `SetEgress` takes.
  final String name;

  /// Human-readable name, for a listing.
  final String label;

  /// The hosts it grants, in the order the file declares them.
  ///
  /// Shown, because a set exists so nobody authors host lists by hand, and that only works if the
  /// name can be seen through.
  final List<String> domains;

  /// Constructor taking every field.
  const EgressSet({required this.name, required this.label, required this.domains});

  /// Reads one from a reply.
  factory EgressSet.from(Map<String, dynamic> map) =>
      EgressSet(name: _string(map, 'name'), label: _string(map, 'label'), domains: _strings(map, 'domains'));
}

/// What a change to a project's egress did, or would do.
///
/// **Every refusal is an outcome, not an exception.** Not a Dart enum, by the rule that already
/// covers [Outcome]: a value added later must render rather than throw.
class EgressOutcome {
  /// Constructor taking the name as the contract spells it.
  const EgressOutcome(this.name);

  /// The value as it came.
  final String name;

  /// Applied and written to the project file.
  static const changed = EgressOutcome('CHANGED');

  /// What it would do. Nothing was written, because `dryRun` was set.
  static const previewed = EgressOutcome('PREVIEWED');

  /// The file already said that.
  static const noChange = EgressOutcome('NO_CHANGE');

  /// A named set is not installed here, so the file would name nothing real.
  static const noSuchSet = EgressOutcome('NO_SUCH_SET');

  /// An offline project declares no egress at all.
  static const refusedByClass = EgressOutcome('REFUSED_BY_CLASS');

  /// The project file could not be read.
  static const unreadable = EgressOutcome('UNREADABLE');

  /// The change was right and the file could not be written — `opens` and `closes` still say what
  /// it would have done.
  static const notWritten = EgressOutcome('NOT_WRITTEN');

  /// The values this build knows.
  static const known = <EgressOutcome>[changed, previewed, noChange, noSuchSet, refusedByClass, unreadable, notWritten];

  /// Whether this build knows what it means.
  bool get recognized => known.any((value) => value.name == name);

  /// Whether anything was actually written.
  bool get wrote => name == 'CHANGED';

  /// Words for a person, unrecognized values included.
  String get label {
    final words = name.toLowerCase().split('_').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return name;
    words[0] = words.first[0].toUpperCase() + words.first.substring(1);
    return words.join(' ');
  }

  @override
  bool operator ==(Object other) => other is EgressOutcome && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => name;
}

/// What a change to a project's egress did, and what it opened and closed.
class EgressChange {
  /// What happened.
  final EgressOutcome outcome;

  /// Hosts the change opens, in the order the sources granted them. **Never sorted.**
  final List<EgressHost> opens;

  /// Hosts it closes, in the same order.
  final List<EgressHost> closes;

  /// A sentence to show prominently, and usually empty.
  ///
  /// Filled only when *this* change makes a forge reachable for a guarded project, and not
  /// repeated on later edits — a warning shown when nothing changed is one people learn to skip.
  final String cost;

  /// Why, in words, for an outcome that needs one.
  final String detail;

  /// Constructor taking every field.
  const EgressChange({
    required this.outcome,
    required this.opens,
    required this.closes,
    required this.cost,
    required this.detail,
  });

  /// Reads one from a reply.
  factory EgressChange.from(Map<String, dynamic> map) => EgressChange(
    outcome: EgressOutcome(_string(map, 'outcome')),
    opens: _list(map, 'opens').map(EgressHost.from).toList(),
    closes: _list(map, 'closes').map(EgressHost.from).toList(),
    cost: _string(map, 'cost'),
    detail: _string(map, 'detail'),
  );
}

/// How far a widening goes.
///
/// **Sent, never received**, which is why this is a Dart enum where [WidenOutcome] is not: the
/// tolerance rule is about values arriving from a backend newer than this build, and nothing
/// arrives here. There is no default and the daemon will not pick one — `ScopeRequired` is the
/// answer to omitting it — because "this run needs it" and "this project needs it" are different
/// intentions and a silent default would make one of them for somebody.
enum Scope {
  /// This run only. **It does not outlive the run**: a resumed task rebuilds its ruleset and its
  /// resolver from what is on disk, and a run-only grant is not on disk.
  run('RUN'),

  /// This run and the project file, so the next task starts with it too.
  runAndProject('RUN_AND_PROJECT');

  const Scope(this.wire);

  /// The value as the contract spells it.
  final String wire;
}

/// What widening a running task did, or would do.
///
/// Not a Dart enum, by the rule that already covers [Outcome] and [EgressOutcome]: a value added
/// later must render rather than throw.
class WidenOutcome {
  /// Constructor taking the name as the contract spells it.
  const WidenOutcome(this.name);

  /// The value as it came.
  final String name;

  /// The running task can reach it now.
  static const widened = WidenOutcome('WIDENED');

  /// It was taken back from the running task.
  ///
  /// **The same type serves both directions**, which is the contract's choice and a good one: the
  /// refusals are identical, so a screen that handled one and not the other would be handling
  /// half of a shared vocabulary.
  static const narrowed = WidenOutcome('NARROWED');

  /// What it would grant. Nothing was changed, because `dryRun` was set.
  static const previewed = WidenOutcome('PREVIEWED');

  /// It could already reach all of that.
  static const noChange = WidenOutcome('NO_CHANGE');

  /// There is no running container to widen.
  static const notRunning = WidenOutcome('NOT_RUNNING');

  /// An offline project's tasks reach nothing, and this is not a way around that.
  static const refusedByClass = WidenOutcome('REFUSED_BY_CLASS');

  /// **The run was widened and the file was not**, because nothing knows where the file is.
  static const noProjectFile = WidenOutcome('NO_PROJECT_FILE');

  /// It did not work, and [Widened.detail] says what happened.
  static const failed = WidenOutcome('FAILED');

  /// **The name is refused on purpose** — by the agent, the project or a repository — so the
  /// resolver would not honour a widening; [Widened.detail] names it and who refuses it.
  static const refusedName = WidenOutcome('REFUSED_NAME');

  /// The values this build knows.
  static const known = <WidenOutcome>[
    widened,
    narrowed,
    previewed,
    noChange,
    notRunning,
    refusedByClass,
    noProjectFile,
    failed,
    refusedName,
  ];

  /// Whether this build knows what it means.
  bool get recognized => known.any((value) => value.name == name);

  /// Whether the change reached the running task.
  ///
  /// `NO_PROJECT_FILE` counts. It is a **partial success**: the run was changed and only the file
  /// was not written. Reading it as a failure tells somebody the task still cannot reach the host
  /// when it can, which is the wrong direction to be wrong in.
  bool get reached => name == 'WIDENED' || name == 'NARROWED' || name == 'NO_PROJECT_FILE';

  /// Whether anything is left to put right.
  ///
  /// `NO_PROJECT_FILE` is not one: nothing broke, and there is nothing to retry.
  bool get failedOutright =>
      name == 'NOT_RUNNING' || name == 'REFUSED_BY_CLASS' || name == 'REFUSED_NAME' || name == 'FAILED';

  /// Words for a person, unrecognized values included.
  String get label {
    final words = name.toLowerCase().split('_').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return name;
    words[0] = words.first[0].toUpperCase() + words.first.substring(1);
    return words.join(' ');
  }

  @override
  bool operator ==(Object other) => other is WidenOutcome && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => name;
}

/// What widening a running task granted, and how far it went.
class Widened {
  /// What happened.
  final WidenOutcome outcome;

  /// The names it grants, in the order they were asked for. **Never sorted**, and names rather
  /// than addresses: a grant covers what is under it.
  final List<String> opens;

  /// Whether the project file was written too, so the next task starts with it.
  ///
  /// Read this rather than the scope that was asked for: asking for `RUN_AND_PROJECT` and getting
  /// `false` is exactly what `NO_PROJECT_FILE` means.
  final bool persisted;

  /// Why, in words, for an outcome that needs one.
  final String detail;

  /// Constructor taking every field.
  const Widened({required this.outcome, required this.opens, required this.persisted, required this.detail});

  /// Reads one from a reply.
  factory Widened.from(Map<String, dynamic> map) => Widened(
    outcome: WidenOutcome(_string(map, 'outcome')),
    opens: (map['opens'] is List) ? (map['opens']! as List).whereType<String>().toList() : const <String>[],
    persisted: map['persisted'] == true,
    detail: _string(map, 'detail'),
  );
}

/// What changing enforcement on a running task did.
///
/// **This never opens a destination by itself.** The ruleset is loaded throughout; what changes is
/// whether a blocked connection produces a question. And it undoes nothing: turning enforcement
/// off does not recall a connection that was already refused — the packet was dropped and nothing
/// retries it — and turning it back on does not recall anything waved through while it was off.
class ClearanceSet {
  /// `CHANGED`, `UNCHANGED`, `PREVIEWED`, `NO_SUCH_TASK`, `NOT_RUNNING`, `UNKNOWN_MODE`,
  /// `NOT_RECORDED` or `FAILED`.
  final String outcome;

  /// The mode before. Empty for a task started before this was recorded.
  final String was;

  /// The mode after. Empty when nothing changed.
  final String now;

  /// Why, in words, for an outcome that needs one.
  final String detail;

  /// Constructor taking every field.
  const ClearanceSet({required this.outcome, required this.was, required this.now, required this.detail});

  /// Reads one from a reply.
  factory ClearanceSet.from(Map<String, dynamic> map) => ClearanceSet(
    outcome: _string(map, 'outcome'),
    was: _string(map, 'was'),
    now: _string(map, 'now'),
    detail: _string(map, 'detail'),
  );

  /// Whether the task is in the mode that was asked for.
  ///
  /// **`UNCHANGED` counts.** It was already in that mode and nothing was restarted — a different
  /// sentence from a change that happened, and not a failure.
  bool get settled => outcome == 'CHANGED' || outcome == 'UNCHANGED';

  /// Whether anything actually moved.
  bool get moved => outcome == 'CHANGED';
}

/// What taking names back from a running task did, and how far it went.
///
/// **It stops new connections and not the ones already running.** The name stops resolving and its
/// recorded addresses come out of the firewall, so nothing new can be reached — but the ruleset
/// accepts established traffic without consulting the set again, so a transfer in progress runs to
/// its end. Nothing may render this as *"the host is now unreachable"*: it is not, yet. Stopping a
/// transfer is what stopping the task does.
class Narrowed {
  /// What happened. The same values as widening, because it is the same kind of change.
  final WidenOutcome outcome;

  /// Names taken back, in the order they were asked for.
  final List<String> closes;

  /// How many addresses came out of the firewall.
  ///
  /// **Zero with a non-empty [closes] is a real state**, not a failure: the name was granted and
  /// the container never reached it, so nothing was in the set to remove.
  ///
  /// These are the addresses recorded when each grant was applied, **never the answer to
  /// resolving the name again now** — a CDN answers the daemon and the container differently, and
  /// the ones that differ are exactly the ones that would be left open.
  final int addresses;

  /// Whether the project file was changed as well.
  final bool persisted;

  /// Why it was refused or what went wrong. Empty otherwise.
  final String detail;

  /// Constructor taking every field.
  const Narrowed({
    required this.outcome,
    required this.closes,
    required this.addresses,
    required this.persisted,
    required this.detail,
  });

  /// Reads one from a reply.
  factory Narrowed.from(Map<String, dynamic> map) => Narrowed(
    outcome: WidenOutcome(_string(map, 'outcome')),
    closes: _strings(map, 'closes'),
    addresses: _int(map, 'addresses'),
    persisted: map['persisted'] == true,
    detail: _string(map, 'detail'),
  );
}

/// One backup that was taken of a project's mirror.
///
/// **A record is not the bundle.** The file can be moved, deleted or replaced afterwards and
/// nothing on the machine would know — so [taken] and [refs] are what was true then, read from a
/// record, and [present] and [bytes] are read from disk now.
class Backup {
  /// When it was written.
  final String taken;

  /// Absolute path on the daemon's machine.
  final String bundle;

  /// How many pushes were waiting for review when it was taken.
  ///
  /// What a restore would bring back, and what somebody gives up by deleting it.
  final int refs;

  /// Whether that file is still there.
  ///
  /// **An absent one is shown rather than quietly dropped**: dropping it would say the backup was
  /// never taken, which is a different and worse statement. It *was* taken, somebody moved it,
  /// and that is exactly the thing they need to see.
  final bool present;

  /// Its size now, or zero when it is gone. **Never what it was when taken.**
  final int bytes;

  /// Constructor taking every field.
  const Backup({
    required this.taken,
    required this.bundle,
    required this.refs,
    required this.present,
    required this.bytes,
  });

  /// Reads one from a reply.
  factory Backup.from(Map<String, dynamic> map) => Backup(
    taken: _string(map, 'taken'),
    bundle: _string(map, 'bundle'),
    refs: _int(map, 'refs'),
    present: map['present'] == true,
    bytes: _int(map, 'bytes'),
  );

  /// When it was taken, or null when the record could not say.
  DateTime? get takenAt => taken.isEmpty ? null : DateTime.tryParse(taken);

  /// Its size in words, or empty when the file is gone.
  String get size {
    if (!present) return '';
    if (bytes < 1024) return '$bytes bytes';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} kB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// What a task holds that never reached the gate.
///
/// **Asked for one task, never on a listing.** Every other field about a task comes from one `ps`
/// and the state directory; this one runs git inside the container, which on a list a client
/// redraws would be a call per row — the cost `since` and `behindMeasured` both exist to avoid.
class HeldWork {
  /// Whether what it holds could be established at all.
  ///
  /// **Not *"holds nothing"*.** Holding nothing is readable with two zeros. Unreadable means
  /// nobody could look: a task killed, or stopped by a Porelo that left no note. Absence rendering
  /// as nothing-to-worry-about is the failure this separation exists to prevent — the same one
  /// that put `readable` on `Credentials` and `Providers`.
  final bool readable;

  /// Files changed and not committed.
  final int changedFiles;

  /// Commits on no remote.
  final int unpushedCommits;

  /// When this was true, or null while the task runs and the answer is current.
  ///
  /// For a stopped task the workspace lives inside a container that is no longer up, so the only
  /// source is what the stop wrote down — and *"holds"* and *"held"* are two different sentences.
  final DateTime? asOf;

  /// Constructor taking every field.
  const HeldWork({required this.readable, required this.changedFiles, required this.unpushedCommits, this.asOf});

  /// Reads one from a reply.
  factory HeldWork.from(Map<String, dynamic> map) {
    final at = map['asOf'];
    return HeldWork(
      readable: map['readable'] == true,
      changedFiles: _int(map, 'changedFiles'),
      unpushedCommits: _int(map, 'unpushedCommits'),
      asOf: at is String && at.isNotEmpty ? DateTime.tryParse(at) : null,
    );
  }

  /// Whether it holds anything at all. **Meaningless unless [readable].**
  bool get holdsSomething => readable && (changedFiles > 0 || unpushedCommits > 0);

  /// Whether the answer is what is true now rather than what was true when it stopped.
  bool get current => asOf == null;
}

/// What asking the upstream how far behind a project is answered.
///
/// **Its own call rather than a flag on a listing**, and that is the point: a listing that reached
/// the network would make the queue cost what a listing must not. It goes through the same
/// measurement the daemon's timer uses and writes the same record, so a triggered fetch and a
/// timed one cannot disagree.
class Synced {
  /// `MEASURED`, `NO_SUCH_PROJECT`, `NO_MIRROR`, `UNREADABLE` or `FAILED`.
  ///
  /// **`NO_MIRROR` is ordinary**: a project that has never used the gate has nothing to measure
  /// against.
  final String outcome;

  /// How many commits the upstream has that this mirror does not.
  ///
  /// **Meaningless unless [measured]** — zero is the answer for a project that is up to date *and*
  /// for one nothing could be measured about.
  final int behind;

  /// Whether the number means anything.
  final bool measured;

  /// What the measurement itself reported: `MEASURED`, `NEVER_CHECKED`, `NO_UPSTREAM`, `OFFLINE`
  /// or `FAILED`.
  final String reason;

  /// Why, in words, for an outcome that needs one.
  final String detail;

  /// Constructor taking every field.
  const Synced({
    required this.outcome,
    required this.behind,
    required this.measured,
    required this.reason,
    required this.detail,
  });

  /// Reads one from a reply.
  factory Synced.from(Map<String, dynamic> map) => Synced(
    outcome: _string(map, 'outcome'),
    behind: _int(map, 'behind'),
    measured: map['measured'] == true,
    reason: _string(map, 'reason'),
    detail: _string(map, 'detail'),
  );
}

/// What restoring a mirror from a backup did, or would do.
///
/// **It refuses rather than decides.** Unreviewed pushes exist only in the mirror — not on the
/// upstream, not in a workspace, not in the bundle — so overwriting one destroys the only copy
/// there has ever been. `force` proceeds and still reports what it destroyed, because somebody who
/// forced needs that afterwards and not only in the warning they clicked past.
class Restored {
  /// `RESTORED`, `PREVIEWED`, `HOLDS_WORK`, `NO_SUCH_PROJECT`, `NO_SUCH_BACKUP` or `FAILED`.
  final String outcome;

  /// The mirror that would be written, or was.
  final String mirror;

  /// Refs nobody reviewed. Non-empty with `HOLDS_WORK`, **and under `force`**.
  final List<String> unreviewed;

  /// Why, in words, for an outcome that needs one.
  final String detail;

  /// Constructor taking every field.
  const Restored({required this.outcome, required this.mirror, required this.unreviewed, required this.detail});

  /// Reads one from a reply.
  factory Restored.from(Map<String, dynamic> map) => Restored(
    outcome: _string(map, 'outcome'),
    mirror: _string(map, 'mirror'),
    unreviewed: _strings(map, 'unreviewed'),
    detail: _string(map, 'detail'),
  );

  /// Whether the mirror was written.
  bool get done => outcome == 'RESTORED';

  /// Whether it refused because work would be destroyed, and can be asked again meaning it.
  bool get holdsWork => outcome == 'HOLDS_WORK';
}

/// What deleting a backup did.
class BackupDeleted {
  /// `DELETED`, `PREVIEWED`, `NO_SUCH_BACKUP` or `FAILED`.
  final String outcome;

  /// Whether the file itself was there to remove.
  ///
  /// **False with `DELETED` means the record was cleared for a bundle somebody had already
  /// moved** — a tidy-up rather than a loss, and worth saying differently.
  final bool fileRemoved;

  /// How many pushes it held, from the record. What somebody is giving up.
  final int refs;

  /// Why, in words, for an outcome that needs one.
  final String detail;

  /// Constructor taking every field.
  const BackupDeleted({required this.outcome, required this.fileRemoved, required this.refs, required this.detail});

  /// Reads one from a reply.
  factory BackupDeleted.from(Map<String, dynamic> map) => BackupDeleted(
    outcome: _string(map, 'outcome'),
    fileRemoved: map['fileRemoved'] == true,
    refs: _int(map, 'refs'),
    detail: _string(map, 'detail'),
  );

  /// Whether it is gone.
  bool get gone => outcome == 'DELETED';
}

/// Something wrong with one answer to the project questions.
class Problem {
  /// Which answer, named as the call named it.
  final String field;

  /// What is wrong with it.
  final String what;

  /// Whether it stops the project being created.
  ///
  /// **A non-fatal one is worth showing and not worth blocking on** — a base image that is not on
  /// the machine yet will simply be pulled, and refusing there would turn a note into a wall.
  final bool fatal;

  /// Constructor taking every field.
  const Problem({required this.field, required this.what, required this.fatal});

  /// Reads one from a reply.
  factory Problem.from(Map<String, dynamic> map) =>
      Problem(field: _string(map, 'field'), what: _string(map, 'what'), fatal: map['fatal'] == true);
}

/// What creating a project did, or would do.
class Created {
  /// `CREATED`, `PREVIEWED`, `ALREADY_EXISTS`, `INVALID` or `FAILED`.
  final String outcome;

  /// The file that was written, or would be.
  final String file;

  /// The file as it would be written, for review.
  ///
  /// **Filled even on a refusal**, because seeing what was rejected is most of understanding why.
  final String content;

  /// What is wrong with the answers.
  final List<Problem> problems;

  /// Why, in words, for an outcome that needs one.
  final String detail;

  /// Constructor taking every field.
  const Created({
    required this.outcome,
    required this.file,
    required this.content,
    required this.problems,
    required this.detail,
  });

  /// Reads one from a reply.
  factory Created.from(Map<String, dynamic> map) => Created(
    outcome: _string(map, 'outcome'),
    file: _string(map, 'file'),
    content: _string(map, 'content'),
    problems: _list(map, 'problems').map(Problem.from).toList(),
    detail: _string(map, 'detail'),
  );

  /// Whether a project file now exists.
  bool get written => outcome == 'CREATED';

  /// Whether this is a review of what would be written.
  bool get previewed => outcome == 'PREVIEWED';

  /// Whether anything stops it being created.
  bool get blocked => problems.any((problem) => problem.fatal);

  /// What is wrong and does not block, which is worth showing beside what does.
  List<Problem> get warnings => problems.where((problem) => !problem.fatal).toList();

  /// What is wrong and blocks.
  List<Problem> get refusals => problems.where((problem) => problem.fatal).toList();
}

/// One thing outside Porelo that a task depends on.
///
/// **Each of these fails far from its cause.** Without `nft` a container comes up with no ruleset;
/// without `nsenter` a clearance decision cannot reach a running task. Today a person learns about
/// them by starting work and watching it behave strangely.
class Probe {
  /// What is being reported, as an operator would name it.
  final String name;

  /// `OK`, `DEGRADED`, `MISSING` or `UNKNOWN` — a string rather than a type, by the rule that
  /// covers every other value here: one added later must render rather than throw.
  final String state;

  /// What was found, in one line.
  final String detail;

  /// The single next action.
  ///
  /// **Empty only when [state] is `OK`.** A probe that fails and names nothing to do about it
  /// cannot be constructed on the Porelo side, so this can be rendered without checking.
  final String action;

  /// Constructor taking every field.
  const Probe({required this.name, required this.state, required this.detail, required this.action});

  /// Reads one from a reply.
  factory Probe.from(Map<String, dynamic> map) => Probe(
    name: _string(map, 'name'),
    state: _string(map, 'state'),
    detail: _string(map, 'detail'),
    action: _string(map, 'action'),
  );

  /// Whether this one stops the machine running tasks at all.
  bool get stopsIt => state == 'MISSING';

  /// Whether it is fine.
  bool get fine => state == 'OK';

  /// Words for a person, unrecognized states included.
  String get label => switch (state) {
    'OK' => 'fine',
    'DEGRADED' => 'works, but not as well as it should',
    'MISSING' => 'missing',
    // **Its own answer, never the good case.** A probe that guesses well is indistinguishable
    // from one that works, so this says so instead of rounding up.
    'UNKNOWN' => 'could not be established',
    _ => state.toLowerCase().replaceAll('_', ' '),
  };
}

/// Whether a machine can actually run a task, and what it is short of.
class Health {
  /// Everything that was probed, in the order it came.
  final List<Probe> probes;

  /// Whether the machine can run tasks.
  ///
  /// **Never re-derived here.** It is false exactly when something is `MISSING`, and it is the
  /// same rule the CLI exits non-zero on — so the two cannot come to different conclusions about
  /// one machine. `DEGRADED` and `UNKNOWN` leave it true: the machine runs tasks, and the probes
  /// say how well.
  final bool ready;

  /// Constructor taking both.
  const Health({required this.probes, required this.ready});

  /// Reads one from a reply.
  factory Health.from(Map<String, dynamic> map) =>
      Health(probes: _list(map, 'probes').map(Probe.from).toList(), ready: map['ready'] == true);

  /// What is not fine, which is what a person came to read.
  List<Probe> get worthReading => probes.where((probe) => !probe.fine).toList();

  /// Whether it runs tasks but has something worth knowing about.
  bool get readyWithCaveats => ready && worthReading.isNotEmpty;
}

/// One provider an agent can authenticate against.
class Provider {
  /// As an agent names it, and as `vault put` takes it.
  final String name;

  /// Human-readable name.
  final String label;

  /// Where it authenticates against.
  final String upstream;

  /// The ways of authenticating it supports.
  final List<String> dialects;

  /// Whether the vault holds a credential for it.
  ///
  /// **Meaningless unless [Providers.readable]** — the same trap as the credential list, where a
  /// locked store and an empty one answered alike.
  final bool authenticated;

  /// `api-key`, `oauth`, or empty when none is stored or none was recorded.
  final String credentialType;

  /// The name a credential for this provider is stored under.
  ///
  /// **Never recomputed here.** It is usually the provider's own name, but a vault written before
  /// credentials were keyed by provider answers under the *agent's* name and that key stays in
  /// use. Intersecting providers with stored names would report a credential missing from
  /// precisely the vault that has one, because the fallback key is invisible from outside.
  final String credentialName;

  /// The exact line to run at the machine to store one. **Rendered verbatim.**
  final String storeCommand;

  /// Constructor taking every field.
  const Provider({
    required this.name,
    required this.label,
    required this.upstream,
    required this.dialects,
    required this.authenticated,
    required this.credentialType,
    required this.credentialName,
    required this.storeCommand,
  });

  /// Reads one from a reply.
  factory Provider.from(Map<String, dynamic> map) => Provider(
    name: _string(map, 'name'),
    label: _string(map, 'label'),
    upstream: _string(map, 'upstream'),
    dialects: _strings(map, 'dialects'),
    authenticated: map['authenticated'] == true,
    credentialType: _string(map, 'credentialType'),
    credentialName: _string(map, 'credentialName'),
    storeCommand: _string(map, 'storeCommand'),
  );
}

/// What providers a machine has, and whether the answer can be believed.
class Providers {
  /// Every provider, in the order it came.
  final List<Provider> providers;

  /// Whether the vault could be read.
  ///
  /// **A vault that does not exist is readable and empty.** There is nothing to unlock, and
  /// telling somebody to unlock it is the one instruction that cannot help them.
  final bool readable;

  /// Constructor taking both.
  const Providers({required this.providers, required this.readable});

  /// Reads one from a reply.
  factory Providers.from(Map<String, dynamic> map) =>
      Providers(providers: _list(map, 'providers').map(Provider.from).toList(), readable: map['readable'] == true);
}

/// What importing an agent's own credential did.
class Imported {
  /// `IMPORTED`, `NO_SUCH_AGENT`, `NO_CONFIG_DIRECTORY`, `NOTHING_TO_IMPORT`, `VAULT_LOCKED` or
  /// `FAILED`.
  final String outcome;

  /// The key it went under.
  final String name;

  /// What kind it is.
  final String type;

  /// How long it is. **Never the value** — this is how somebody sees it worked without seeing
  /// what worked.
  final int length;

  /// Where it was read from.
  final String source;

  /// Why, in words, for an outcome that needs one.
  final String detail;

  /// Constructor taking every field.
  const Imported({
    required this.outcome,
    required this.name,
    required this.type,
    required this.length,
    required this.source,
    required this.detail,
  });

  /// Reads one from a reply.
  factory Imported.from(Map<String, dynamic> map) => Imported(
    outcome: _string(map, 'outcome'),
    name: _string(map, 'name'),
    type: _string(map, 'type'),
    length: _int(map, 'length'),
    source: _string(map, 'source'),
    detail: _string(map, 'detail'),
  );

  /// Whether a credential is now in the vault.
  bool get stored => outcome == 'IMPORTED';

  /// Whether nobody has logged in with that agent here yet.
  ///
  /// **Ordinary, not a fault.** The agent is installed and nothing has been done with it, which
  /// is a sentence with a next step rather than a failure.
  bool get nothingYet => outcome == 'NOTHING_TO_IMPORT';

  /// Whether the store was shut. **Not a missing credential**, and must not be drawn as one.
  bool get shut => outcome == 'VAULT_LOCKED';
}

/// One thing a project deletion removes.
class Removal {
  /// `MIRROR`, `IMAGE`, `BUILD`, `REGISTRY`, `UPSTREAM_RECORD` or `TASK` — a string rather than a
  /// type, by the rule that covers every other value here: a kind added later must render.
  final String kind;

  /// The thing itself — a path, an image name, a container name — as a person would recognize it.
  final String what;

  /// Constructor taking both.
  const Removal({required this.kind, required this.what});

  /// Reads one from a reply.
  factory Removal.from(Map<String, dynamic> map) => Removal(kind: _string(map, 'kind'), what: _string(map, 'what'));

  /// Words for a person, unrecognized kinds included.
  String get label => switch (kind) {
    'MIRROR' => 'the mirror',
    'IMAGE' => 'the image',
    'BUILD' => 'the build directory',
    'REGISTRY' => 'its entry in the registry',
    'UPSTREAM_RECORD' => 'the recorded upstream distance',
    'TASK' => 'a task, with its container, state and logs',
    _ => kind.toLowerCase().replaceAll('_', ' '),
  };
}

/// What removing what Porelo built for a project did, or would do.
class DeleteOutcome {
  /// Constructor taking the name as the contract spells it.
  const DeleteOutcome(this.name);

  /// The value as it came.
  final String name;

  /// Everything Porelo built for it is gone.
  static const deleted = DeleteOutcome('DELETED');

  /// What would go, having removed nothing.
  static const previewed = DeleteOutcome('PREVIEWED');

  /// Refused: work reached the gate and nobody reviewed it.
  static const holdsWork = DeleteOutcome('HOLDS_WORK');

  /// Refused: tasks are still up.
  static const tasksRunning = DeleteOutcome('TASKS_RUNNING');

  /// Nothing there knows that project.
  static const noSuchProject = DeleteOutcome('NO_SUCH_PROJECT');

  /// Something could not be removed. [Deletion.detail] says what.
  static const failed = DeleteOutcome('FAILED');

  /// The values this build knows.
  static const known = <DeleteOutcome>[deleted, previewed, holdsWork, tasksRunning, noSuchProject, failed];

  /// Whether this build knows what it means.
  bool get recognized => known.any((value) => value.name == name);

  /// Whether it refused rather than deciding, and can be asked again with `force`.
  ///
  /// **Only these two.** `FAILED` is not one — something went wrong rather than being declined,
  /// and offering to force past it would be offering to repeat it.
  bool get canBeForced => name == 'HOLDS_WORK' || name == 'TASKS_RUNNING';

  /// Words for a person, unrecognized values included.
  String get label {
    final words = name.toLowerCase().split('_').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return name;
    words[0] = words.first[0].toUpperCase() + words.first.substring(1);
    return words.join(' ');
  }

  @override
  bool operator ==(Object other) => other is DeleteOutcome && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => name;
}

/// What a deletion removed, or would remove — and what it left alone.
///
/// **`keeps` is the field that makes this safe to offer.** The project file is the operator's, in
/// their own directory, and so are their checkout and their real upstream: none is touched, and
/// naming them means a confirmation can say so without this end having to know which things are
/// Porelo's. Afterwards a task run in that directory builds all of it again.
class Deletion {
  /// What happened, or would have.
  final DeleteOutcome outcome;

  /// What goes, or went. Filled for a refusal too, so the cost can be shown beside the reason.
  final List<Removal> removes;

  /// What is deliberately not touched, named.
  final List<String> keeps;

  /// Refs nobody reviewed. Non-empty with `HOLDS_WORK`, and under `force` — it is what force
  /// destroys.
  final List<String> unreviewed;

  /// Tasks that are up. Non-empty with `TASKS_RUNNING`, and under `force`.
  final List<String> running;

  /// Why it was refused, or what went wrong. Empty otherwise.
  final String detail;

  /// Constructor taking every field.
  const Deletion({
    required this.outcome,
    required this.removes,
    required this.keeps,
    required this.unreviewed,
    required this.running,
    required this.detail,
    this.keys = const <MachineDeployKey>[],
    this.signer,
  });

  /// This machine's deploy keys for the project, forgotten with it: each is removed at the forge.
  final List<MachineDeployKey> keys;

  /// This machine's message key, whose line the project's `machine-signers` should lose; null from a
  /// machine that does not say.
  final MachineKey? signer;

  /// Reads one from a reply.
  factory Deletion.from(Map<String, dynamic> map) => Deletion(
    outcome: DeleteOutcome(_string(map, 'outcome')),
    removes: (map['removes'] is List)
        ? (map['removes']! as List).whereType<Map<String, dynamic>>().map(Removal.from).toList()
        : const <Removal>[],
    keeps: _strings(map, 'keeps'),
    unreviewed: _strings(map, 'unreviewed'),
    running: _strings(map, 'running'),
    detail: _string(map, 'detail'),
    keys: <MachineDeployKey>[
      if (map['keys'] case final List<dynamic> keys)
        for (final each in keys)
          if (each is Map<String, dynamic>) MachineDeployKey.from(each),
    ],
    signer: map['signer'] is Map<String, dynamic> ? MachineKey.from(map['signer'] as Map<String, dynamic>) : null,
  );

  /// How many tasks would go with it, which is the number people react to.
  int get tasks => removes.where((each) => each.kind == 'TASK').length;
}

/// What setting or clearing a caption did.
class Labelled {
  /// `LABELLED`, `CLEARED`, `NOT_A_TASK`, `NOT_RECORDED` or `FAILED`.
  ///
  /// A string rather than an enum, by the rule that already covers [Outcome]: a value added later
  /// must render rather than throw.
  final String outcome;

  /// The caption as it now stands. Empty when it was cleared.
  final String label;

  /// Constructor taking both.
  const Labelled({required this.outcome, required this.label});

  /// Reads one from a reply.
  factory Labelled.from(Map<String, dynamic> map) =>
      Labelled(outcome: _string(map, 'outcome'), label: _string(map, 'label'));

  /// Whether anything changed.
  bool get worked => outcome == 'LABELLED' || outcome == 'CLEARED';

  /// Words for a person.
  String get words => switch (outcome) {
    'LABELLED' => 'It reads as "$label" now. Its real name has not moved.',
    'CLEARED' => 'The caption is gone. It reads as its own name again.',
    'NOT_A_TASK' => 'There is no work by that name here.',
    // Started by an older Porelo, which recorded nothing to write a caption into. A state, not
    // a failure of this action.
    'NOT_RECORDED' => 'This was started by an older Porelo, which kept nowhere to write a caption.',
    'FAILED' => 'That did not work.',
    _ => outcome.toLowerCase().replaceAll('_', ' '),
  };
}

/// Whether work can start, and what stands in the way.
///
/// **Not a Dart enum**, by the rule that already covers [Outcome]: a value added later must render
/// rather than throw.
class StartOutcome {
  /// Constructor taking the name as the contract spells it.
  const StartOutcome(this.name);

  /// The value as it came.
  final String name;

  /// Everything is in place.
  static const ready = StartOutcome('READY');

  /// Nothing is installed to run.
  static const noAgent = StartOutcome('NO_AGENT');

  /// The named agent is not installed here.
  static const unknownAgent = StartOutcome('UNKNOWN_AGENT');

  /// More than one is installed and none was named.
  static const severalAgents = StartOutcome('SEVERAL_AGENTS');

  /// The agent names no default provider, so one has to be chosen. **A provider, not a secret.**
  static const noProviderChosen = StartOutcome('NO_PROVIDER_CHOSEN');

  /// The named provider is not one this machine knows.
  static const unknownProvider = StartOutcome('UNKNOWN_PROVIDER');

  /// The provider does not speak what the agent expects.
  static const wrongDialect = StartOutcome('WRONG_DIALECT');

  /// Nothing recorded a project file, so there is nothing to start against.
  static const noProjectFile = StartOutcome('NO_PROJECT_FILE');

  /// The vault holds no credential under the name that was looked for. **Storing a secret.**
  static const credentialMissing = StartOutcome('CREDENTIAL_MISSING');

  /// There is a credential and it cannot be used as this provider needs it.
  static const credentialUnusable = StartOutcome('CREDENTIAL_UNUSABLE');

  /// The vault is shut, so nothing can say what it holds. **Unlocking, at the machine.**
  static const vaultLocked = StartOutcome('VAULT_LOCKED');

  /// The task name is not one a task can have. `detail` names the rule and, where one exists, a
  /// name that would do. **Retyping the name**, nothing else.
  static const badTaskName = StartOutcome('BAD_TASK_NAME');

  /// No repository was named, and Porelo never picks one. **The start dialog's required
  /// choice**, the way [severalAgents] is the agent's; `detail` names what there is.
  static const noRepositoryChosen = StartOutcome('NO_REPOSITORY_CHOSEN');

  /// A repository was named that the project does not have. `detail` lists what it has.
  static const unknownRepository = StartOutcome('UNKNOWN_REPOSITORY');

  /// A credential the project or the run names is for a destination nobody declared here, or the
  /// run points one of the project's elsewhere. `credential` names it, `detail` says which named it.
  static const unknownDestination = StartOutcome('UNKNOWN_DESTINATION');

  /// An entry a person grants in a browser has no grant yet. `credential` names it, `detail` gives
  /// the command that grants it. **Granting, once**: not storing a secret, not unlocking.
  static const authorizationNeeded = StartOutcome('AUTHORIZATION_NEEDED');

  /// The values this build knows.
  static const known = <StartOutcome>[
    ready,
    badTaskName,
    noAgent,
    unknownAgent,
    severalAgents,
    noProviderChosen,
    unknownProvider,
    wrongDialect,
    noProjectFile,
    credentialMissing,
    credentialUnusable,
    vaultLocked,
    noRepositoryChosen,
    unknownRepository,
    unknownDestination,
    authorizationNeeded,
  ];

  /// Whether this build knows what it means.
  bool get recognized => known.any((value) => value.name == name);

  /// Whether this is answered at the machine rather than here.
  ///
  /// A daemon has no terminal to take a passphrase at, so unlocking is not something this
  /// interface can offer — and saying *"this happens at the machine"* is a different sentence from
  /// *"this cannot be done"*.
  bool get answeredAtTheMachine => name == 'VAULT_LOCKED';

  @override
  bool operator ==(Object other) => other is StartOutcome && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => name;
}

/// Whether a run can start, asked before anything is created.
///
/// The rule it answers lives on the daemon and is not restated here: which credential a run needs
/// turns on the agent's declaration, the installed providers, the run's own override **and what
/// the vault already holds** — an older vault answers under the agent's name rather than the
/// provider's. A client holds one of the four.
class Readiness {
  /// Whether work can start.
  ///
  /// Never disagrees with [outcome]: `READY` is the only value that sets it.
  final bool ready;

  /// What stands in the way, or `READY`.
  final StartOutcome outcome;

  /// The agent that would run.
  final String agent;

  /// The provider that would be used.
  final String provider;

  /// **The key that was actually looked for**, not the one that ought to apply.
  ///
  /// A vault written before the provider-keyed change answers under the agent's own name, so the
  /// name to show is the one the daemon looked up. Naming the other would tell somebody a key is
  /// missing from a vault that has it.
  final String credential;

  /// Prose for a person. **Never parsed.**
  final String detail;

  /// With `CREDENTIAL_MISSING`, what to run on the machine to store it, as arguments; empty otherwise
  /// and from a Porelo older than the field.
  final List<String> storeCommand;

  /// With `UNKNOWN_HOST_KEY` and `HOST_KEY_CHANGED`, the repository's host the machine has never met
  /// (or met with another key); empty otherwise.
  final String host;

  /// The keys that host offers now, with those outcomes.
  final List<HostKey> hostKeys;

  /// Constructor taking every field.
  const Readiness({
    required this.ready,
    required this.outcome,
    required this.agent,
    required this.provider,
    required this.credential,
    required this.detail,
    this.storeCommand = const <String>[],
    this.host = '',
    this.hostKeys = const <HostKey>[],
  });

  /// The same answer, naming [chosen] where the machine named no agent: a refusal about an agent
  /// said without its name reads " is not installed on this machine.".
  Readiness naming(String? chosen) => agent.isNotEmpty || chosen == null || chosen.isEmpty
      ? this
      : Readiness(
          ready: ready,
          outcome: outcome,
          agent: chosen,
          provider: provider,
          credential: credential,
          detail: detail,
          storeCommand: storeCommand,
          host: host,
          hostKeys: hostKeys,
        );

  /// Reads one from a reply.
  factory Readiness.from(Map<String, dynamic> map) => Readiness(
    ready: map['ready'] == true,
    outcome: StartOutcome(_string(map, 'outcome')),
    agent: _string(map, 'agent'),
    provider: _string(map, 'provider'),
    credential: _string(map, 'credential'),
    detail: _string(map, 'detail'),
    storeCommand: _strings(map, 'storeCommand'),
    host: _string(map, 'host'),
    hostKeys: map['hostKeys'] is List
        ? (map['hostKeys'] as List).whereType<Map<String, dynamic>>().map(HostKey.from).toList()
        : const <HostKey>[],
  );

  /// What to do about it, in one line, or empty when there is nothing to do.
  ///
  /// **Three of these are different actions**, and confusing them sends somebody to the wrong
  /// place: choosing a provider is not storing a secret, and neither is unlocking a vault.
  String get whatToDo => switch (outcome.name) {
    'READY' => '',
    'NO_PROVIDER_CHOSEN' => 'This agent names no default provider. Choose one — this is a provider, not a secret.',
    'CREDENTIAL_MISSING' =>
      credential.isEmpty
          ? 'The vault holds no credential for this.'
          : 'The vault holds no credential called $credential. Store one and try again.',
    'CREDENTIAL_UNUSABLE' =>
      'There is a credential called $credential and it cannot be used the way this provider '
          'needs it.',
    'VAULT_LOCKED' =>
      'The vault is shut, so nothing here can say what it holds. Unlock it at the machine: '
          'a daemon has no terminal to take a passphrase at.',
    'NO_AGENT' => 'Nothing is installed here to run work with.',
    'UNKNOWN_AGENT' => '$agent is not installed on this machine.',
    'UNKNOWN_HOST_KEY' =>
      'This machine has never met ${host.isEmpty ? 'the repository’s host' : host}, so '
          'it cannot fetch from there yet. Trust its key first.',
    'HOST_KEY_CHANGED' =>
      '${host.isEmpty ? 'The repository’s host' : host} offers another key than the one '
          'this machine remembers. That is what somebody in between looks like: find out why before going on.',
    'SEVERAL_AGENTS' => 'More than one agent is installed. Choose which to run.',
    'UNKNOWN_PROVIDER' => '$provider is not a provider this machine knows.',
    'WRONG_DIALECT' => '$provider does not speak what $agent expects.',
    'NO_PROJECT_FILE' => 'No project file is recorded, and starting takes one.',
    'BAD_TASK_NAME' => detail.isEmpty ? 'This is not a name a task can have.' : detail,
    'NO_REPOSITORY_CHOSEN' => 'Choose which repository the work starts in.',
    'UNKNOWN_REPOSITORY' => detail.isEmpty ? 'The project has no repository of that name.' : detail,
    'AUTHORIZATION_NEEDED' =>
      'Nobody has granted $credential yet. It is granted once, in a browser, and later tasks use it.',
    'UNKNOWN_DESTINATION' =>
      detail.isEmpty ? '$credential is for a destination this machine does not declare.' : detail,
    // Added after this build shipped: the daemon's own words rather than silence.
    _ => detail.isEmpty ? 'This cannot start, and nothing said why.' : detail,
  };
}

/// One piece of work an emergency stop reached.
class PanickedTask {
  /// The container name of the work that was stopped.
  ///
  /// **Not what `Start` takes**: bringing the work back is `Start` with its project and the name
  /// within the project, [Task.task], which is carried on the listed task and never cut from this.
  final String name;

  /// How many helper processes it had.
  final int helpers;

  /// Its helpers that outlived the stop. Empty is the normal case.
  final List<String> surviving;

  /// Constructor taking every field.
  const PanickedTask({required this.name, required this.helpers, required this.surviving});

  /// Reads one from a reply.
  factory PanickedTask.from(Map<String, dynamic> map) =>
      PanickedTask(name: _string(map, 'name'), helpers: _int(map, 'helpers'), surviving: _strings(map, 'surviving'));
}

/// What an emergency stop did.
///
/// **It stops and never removes.** Every workspace, every log and every commit that never reached
/// the gate is exactly where it was, and `Start` brings a task back with the work it had. An
/// interface that presented this as a cleanup would send somebody looking for work that is still
/// there — which is why what this carries is *what survived*, not what was cleared away.
class Panicked {
  /// The work it reached.
  ///
  /// **Every task that was *running* when the call arrived, and no other.** A task that was
  /// already stopped is absent rather than listed — so *"stopped the 3 that were running"* is
  /// honest and *"stopped 3 of 7"* is not: this call never saw the other four, and somebody who
  /// reads *"of 7"* goes looking for what happened to them.
  final List<PanickedTask> tasks;

  /// Every helper that outlived its stop, across all of them, **by name**.
  ///
  /// A flattening of the per-task lists rather than a second source: nothing can appear here whose
  /// task is not in [tasks]. Named rather than counted because a person has to kill these by hand,
  /// and a number is not something anybody can act on.
  final List<String> surviving;

  /// Whether this was a preview and nothing was actually stopped.
  ///
  /// **Then every `surviving` is empty because nothing was attempted**, not because nothing would
  /// survive. Rendering a dry run's empty list as *"everything will stop cleanly"* would be a
  /// promise made out of an absence of evidence.
  final bool previewed;

  /// How many pieces of work it reached.
  int get stopped => tasks.length;

  /// Constructor taking every field.
  const Panicked({required this.tasks, required this.surviving, required this.previewed});

  /// Reads one from a reply.
  factory Panicked.from(Map<String, dynamic> map) => Panicked(
    tasks: _list(map, 'tasks').map(PanickedTask.from).toList(),
    surviving: _strings(map, 'surviving'),
    previewed: map['previewed'] == true,
  );
}

/// One of a task's log files.
class Log {
  /// File name. **Pass it to `Tail` unchanged** — it is a name, never a path.
  final String name;

  /// What the file holds, in one line, or null where the name speaks for itself.
  ///
  /// **It comes from the daemon and is never composed here.** Only that end knows which files a
  /// task has and what each one is for, and it grows when the file list grows because both come
  /// from the same place. A table at this end would say nothing about a file added tomorrow while
  /// looking exactly as authoritative about it.
  final String? what;

  /// How large it is right now. A tail that is running will pass it, so it is a size to show or
  /// to decide by, never a total to count down from.
  final int bytes;

  /// When it was last written, ISO-8601.
  final String at;

  /// Constructor taking every field.
  const Log({required this.name, required this.bytes, required this.at, this.what});

  /// Reads one from a reply.
  factory Log.from(Map<String, dynamic> map) => Log(
    name: _string(map, 'name'),
    bytes: _int(map, 'bytes'),
    at: _string(map, 'at'),
    // Absent, empty and whitespace all mean the same thing: nothing to say. A blank line under
    // a name would read as a description that failed rather than as one that was never given.
    what: _optional(map, 'what'),
  );
}

/// A push waiting at the gate for a decision.
class PendingPush {
  /// Ref name, which reviewing, approving and rejecting all take.
  final String name;

  /// Commit at the tip.
  final String commit;

  /// First line of its message.
  final String subject;

  /// How long it has been waiting, as words.
  final String waiting;

  /// When it arrived, ISO-8601.
  final String at;

  /// Which of the project's repositories it waits in, or empty where the gate was asked about none.
  ///
  /// Not in the reply: the gate is asked one repository at a time, and this is which one it was.
  final String repository;

  /// The `git fetch` that brings it into the person's own clone over their ssh, as the machine
  /// names it, or empty from a machine that does not. Reading only: the work is not reviewed.
  final String fetch;

  /// Constructor taking every field.
  const PendingPush({
    required this.name,
    required this.commit,
    required this.subject,
    required this.waiting,
    required this.at,
    this.repository = '',
    this.fetch = '',
  });

  /// [fetch], with the host the machine named for itself replaced by [login] (`user@host`), the
  /// one this computer reaches it by; as the machine named it where [login] is null or the fetch
  /// is not an `ssh://` address.
  String fetchFrom(String? login) {
    if (login == null || login.isEmpty) return fetch;
    final at = RegExp(r'ssh://[^/\s]+');
    return fetch.contains(at) ? fetch.replaceFirst(at, 'ssh://$login') : fetch;
  }

  /// The same push, waiting in [repository].
  PendingPush inRepository(String repository) => PendingPush(
    name: name,
    commit: commit,
    subject: subject,
    waiting: waiting,
    at: at,
    repository: repository,
    fetch: fetch,
  );

  /// What tells it apart: the same ref name can wait in two repositories. A colon is not allowed
  /// in a ref name, so it cannot be part of one.
  String get id => repository.isEmpty ? name : '$repository:$name';

  /// Reads one from a reply.
  factory PendingPush.from(Map<String, dynamic> map) => PendingPush(
    name: _string(map, 'name'),
    commit: _string(map, 'commit'),
    subject: _string(map, 'subject'),
    waiting: _string(map, 'waiting'),
    at: _string(map, 'at'),
    fetch: map['fetch'] is String ? map['fetch'] as String : '',
  );
}

/// A connection a task tried to make and was stopped for.
///
/// The task is blocked while this goes unanswered and the watcher gives up on its own timeout, so
/// this is the one place where interface latency costs something real.
class Prompt {
  /// Container name, for routing the answer back.
  final String task;

  /// Pass this back unchanged when deciding. **Never rebuild it** - it is derived, and a client
  /// that got the derivation wrong would answer a prompt that does not exist.
  final String key;

  /// Host or address the task asked for.
  final String destination;

  /// `tcp` or `udp`.
  final String protocol;

  /// Port, or zero when there is none.
  final int port;

  /// When it was blocked, ISO-8601.
  final String at;

  /// Where in the ruleset it was stopped. Empty on an event carrying a [verdict] — nothing
  /// decided it a second time.
  final String prefix;

  /// Absent while the question is open; `allow`, `deny` or `timeout` once it is settled.
  ///
  /// A plain string on purpose. The contract declares it as one rather than as an enumeration,
  /// and a closed Dart enum is exactly how the tolerance rule gets broken.
  final String? verdict;

  /// When it runs out, ISO-8601, measured from when it was asked. `""` is one that never runs out;
  /// null is a daemon older than the field, which says nothing either way.
  final String? deadline;

  /// Constructor taking every field.
  const Prompt({
    required this.task,
    required this.key,
    required this.destination,
    required this.protocol,
    required this.port,
    required this.at,
    required this.prefix,
    this.verdict,
    this.deadline,
    this.missed = 0,
  });

  /// How many questions the machine dropped before this reply, because the stream was read too
  /// slowly. A dropped question is not asked again, so a person has to be told some may wait unseen.
  final int missed;

  /// Reads one from a reply.
  factory Prompt.from(Map<String, dynamic> map) => Prompt(
    task: _string(map, 'task'),
    key: _string(map, 'key'),
    destination: _string(map, 'destination'),
    protocol: _string(map, 'protocol'),
    port: _int(map, 'port'),
    at: _string(map, 'at'),
    prefix: _string(map, 'prefix'),
    // Genuinely absent rather than empty, which is the difference between an open question
    // and one that was settled by something this build has never heard of.
    verdict: map['verdict'] is String ? map['verdict'] as String : null,
    // Not `_optional`: absent and empty are different answers here.
    deadline: map['deadline'] is String ? map['deadline'] as String : null,
    missed: _int(map, 'missed'),
  );

  /// When it runs out, or null when nothing says or it never does.
  DateTime? get expiresAt => deadline == null || deadline!.isEmpty ? null : DateTime.tryParse(deadline!);

  /// Whether the daemon said this one never runs out, as opposed to saying nothing.
  bool get neverRunsOut => deadline != null && deadline!.isEmpty;

  /// Destination as it should be shown: with the port, unless there is none.
  String get shown => port == 0 ? destination : '$destination:$port';

  /// Whether this event is an answer rather than a question.
  bool get settled => verdict != null;

  /// Whether it ran out rather than being answered.
  ///
  /// The only way to learn that: nothing asks about an expired prompt again, so a question that
  /// simply stops arriving is otherwise indistinguishable from one still waiting for its
  /// operator. `Decide` still works on one, and still takes effect.
  bool get expired => verdict == 'timeout';

  /// What identifies one prompt across the question and the answer to it.
  ///
  /// `task` and `key`, and nothing else. The answer arrives as the same destination a second
  /// time, so anything that keyed on a field which differs between the two — [at] carries the
  /// block time on one and the decision time on the other, [prefix] is empty on the answer —
  /// would show every blocked destination twice.
  String get identity => '$task/$key';
}

/// What a stop did. A stop keeps the task: its container is its workspace.
class Stopped {
  /// What became of it.
  final Outcome outcome;

  /// How many helpers were stopped.
  final int helpers;

  /// How many helpers outlived the stop and have to be killed by hand: `Stop`'s `surviving` is a
  /// count. Zero is the normal case.
  final int surviving;

  /// What the machine adds in its own words, or empty.
  final String detail;

  /// Constructor taking every field.
  const Stopped({required this.outcome, required this.helpers, required this.surviving, this.detail = ''});

  /// Reads one from a reply.
  factory Stopped.from(Map<String, dynamic> map) => Stopped(
    outcome: Outcome(_string(map, 'outcome')),
    helpers: _int(map, 'helpers'),
    surviving: _int(map, 'surviving'),
    detail: _string(map, 'detail'),
  );
}

/// What a removal did, or refused to do.
class Removed {
  /// What became of it.
  final Outcome outcome;

  /// What the task holds, when that is why it was refused.
  final String work;

  /// Where rescued work was put, when it was rescued.
  final String rescuedRef;

  /// Whether the container was removed.
  final bool removed;

  /// How many paths the container held that its image did not, gone with it: `Remove`'s
  /// `discarded` is a count of paths, not bytes. Zero when unknown.
  final int discarded;

  /// What the machine adds in its own words, or empty: a refusal's or a failure's reason.
  final String detail;

  /// Constructor taking every field.
  const Removed({
    required this.outcome,
    required this.work,
    required this.rescuedRef,
    required this.removed,
    required this.discarded,
    this.detail = '',
  });

  /// Reads one from a reply.
  factory Removed.from(Map<String, dynamic> map) => Removed(
    outcome: Outcome(_string(map, 'outcome')),
    work: _string(map, 'work'),
    rescuedRef: _string(map, 'rescuedRef'),
    removed: map['removed'] == true,
    discarded: _int(map, 'discarded'),
    detail: _string(map, 'detail'),
  );
}

/// What the vault holds, without any of it.
class VaultState {
  /// Where the vault file is.
  final String vault;

  /// Whether that file exists.
  final bool exists;

  /// What is in it, by name only.
  final List<Credential> credentials;

  /// Whether the list can be believed.
  ///
  /// An empty list from a locked vault and an empty list from an empty vault are different
  /// things, and an interface must not show them the same way.
  final bool readable;

  /// What this machine is configured to connect out with. **Readable with the vault shut**, because
  /// it holds no secret — which is what tells *"configured, open the vault"* from *"nothing here"*.
  /// Empty from a Porelo that has no connections, and never read as *no credential*: an undeclared
  /// git host still falls back to vault entries named after it.
  final List<Connection> connections;

  /// Constructor taking every field.
  const VaultState({
    required this.vault,
    required this.exists,
    required this.credentials,
    required this.readable,
    this.connections = const <Connection>[],
  });

  /// Reads one from a reply.
  factory VaultState.from(Map<String, dynamic> map) => VaultState(
    vault: _string(map, 'vault'),
    exists: map['exists'] == true,
    credentials: _list(map, 'credentials').map(Credential.from).toList(),
    readable: map['readable'] == true,
    connections: _list(map, 'connections').map(Connection.from).toList(),
  );
}

/// What the gate has waiting for a project.
class GateState {
  /// Path to the bare mirror the agent pushes into.
  final String mirror;

  /// `offline`, `gatekeeping` or `online`.
  final String mode;

  /// Where the mirror was seeded from, or empty.
  final String seededFrom;

  /// What is waiting.
  final List<PendingPush> pending;

  /// Constructor taking every field.
  const GateState({required this.mirror, required this.mode, required this.seededFrom, required this.pending});

  /// Reads one from a reply.
  factory GateState.from(Map<String, dynamic> map) => GateState(
    mirror: _string(map, 'mirror'),
    mode: _string(map, 'mode'),
    seededFrom: _string(map, 'seededFrom'),
    pending: _list(map, 'pending').map(PendingPush.from).toList(),
  );
}

/// What a backend says it is.
class ServiceInfo {
  /// Product name.
  final String product;

  /// Build version. **Show it; never gate a feature on it.**
  final String version;

  /// Who publishes it.
  final String vendor;

  /// Interfaces it serves.
  final List<String> interfaces;

  /// Constructor taking every field.
  const ServiceInfo({required this.product, required this.version, required this.vendor, required this.interfaces});

  /// Reads one from a reply.
  factory ServiceInfo.from(Map<String, dynamic> map) => ServiceInfo(
    product: _string(map, 'product'),
    version: _string(map, 'version'),
    vendor: _string(map, 'vendor'),
    interfaces: _strings(map, 'interfaces'),
  );
}

// Readers that never throw on a shape the backend did not promise. New reply fields are expected
// and ignored; a missing one reads as empty rather than as a crash, because a client that dies on
// an unfamiliar reply is a client that dies on a routine backend release.

/// A map of strings from a reply, leaving out any value that is not one.
Map<String, String> _stringMap(Map<String, dynamic> map, String key) => <String, String>{
  if (map[key] case final Map<String, dynamic> each)
    for (final entry in each.entries)
      if (entry.value is String) entry.key: entry.value as String,
};

String _string(Map<String, dynamic> map, String key) {
  final value = map[key];
  return value is String ? value : '';
}

/// A string that may be absent, where absent and blank mean the same thing: nothing was said.
///
/// **Not `_string`.** An empty string rendered where a sentence belongs is a blank that looks like
/// an answer — the reader sees a field that failed rather than one that was never given.
String? _optional(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! String) return null;
  final said = value.trim();
  return said.isEmpty ? null : said;
}

int _int(Map<String, dynamic> map, String key) {
  final value = map[key];
  return value is num ? value.toInt() : 0;
}

List<String> _strings(Map<String, dynamic> map, String key) {
  final value = map[key];
  return value is List ? value.whereType<String>().toList() : const [];
}

List<Map<String, dynamic>> _list(Map<String, dynamic> map, String key) {
  final value = map[key];
  return value is List ? value.whereType<Map<String, dynamic>>().toList() : const [];
}

/// One repository a project names, and how far it has got.
class Repository {
  /// Its name, which `Start`, the gate methods, `Backups`, `RestoreBackup` and `SyncUpstream` take.
  final String name;

  /// Whether it is the project's own: its file, its planning, its issues.
  final bool own;

  /// Where it is followed from, or empty.
  final String upstream;

  /// Path to its bare mirror.
  final String mirror;

  /// How many pushes wait at its gate.
  final int pending;

  /// How many commits its mirror is behind its upstream. **Meaningless unless [behindReason] is
  /// `MEASURED`**, exactly as on the project.
  final int behind;

  /// When [behind] was measured, RFC 3339. Empty when it never was.
  final String behindMeasured;

  /// Why [behind] says what it says, in the project's words for it.
  final String behindReason;

  /// Prose for a person, only when [behindReason] is `FAILED`. Never parsed.
  final String behindDetail;

  /// What a task on it may consume, or null from a Porelo that does not say.
  final ResolvedLimits? limits;

  /// Whether it is behind its upstream by an amount somebody can act on.
  bool get hasFallenBehind => behindReason == 'MEASURED' && behind > 0;

  /// How far behind it is, in the same words as a project's.
  String get behindWords => _behindWords(behindReason, behind, behindMeasured, behindDetail);

  /// Constructor taking every field.
  const Repository({
    required this.name,
    this.own = false,
    this.upstream = '',
    this.mirror = '',
    this.pending = 0,
    this.behind = 0,
    this.behindMeasured = '',
    this.behindReason = '',
    this.behindDetail = '',
    this.limits,
  });

  /// Reads one from a reply.
  factory Repository.from(Map<String, dynamic> map) => Repository(
    name: _string(map, 'name'),
    own: map['own'] == true,
    upstream: _string(map, 'upstream'),
    mirror: _string(map, 'mirror'),
    pending: _int(map, 'pending'),
    behind: _int(map, 'behind'),
    behindMeasured: _string(map, 'behindMeasured'),
    behindReason: _string(map, 'behindReason'),
    behindDetail: _string(map, 'behindDetail'),
    limits: map['limits'] is Map<String, dynamic> ? ResolvedLimits.from(map['limits']! as Map<String, dynamic>) : null,
  );

  /// A project's repositories, **the project's own first**, from either shape Porelo has answered:
  /// names alone, as it first did, or an object each, as it does since. One without a name is
  /// left out — nothing could be started in it or asked about it.
  static List<Repository> allIn(Map<String, dynamic> project) {
    final value = project['repositories'];
    if (value is! List) return const <Repository>[];
    final all = <Repository>[
      for (final each in value)
        if (each is String) Repository(name: each) else if (each is Map<String, dynamic>) Repository.from(each),
    ].where((each) => each.name.isNotEmpty).toList();
    return <Repository>[...all.where((each) => each.own), ...all.where((each) => !each.own)];
  }
}

/// How far behind its upstream something is, in one line — a project, or one of its repositories.
String _behindWords(String reason, int behind, String measured, String detail) {
  String asOf() {
    final when = DateTime.tryParse(measured);
    if (when == null) return '';
    final ago = DateTime.now().difference(when);
    if (ago.isNegative || ago.inMinutes < 1) return ', measured just now';
    if (ago.inMinutes < 60) return ', as of ${ago.inMinutes} minutes ago';
    if (ago.inHours < 48) return ', as of ${ago.inHours} hours ago';
    return ', as of ${ago.inDays} days ago';
  }

  return switch (reason) {
    'MEASURED' when behind == 0 => 'Up to date${asOf()}',
    'MEASURED' => '$behind behind${asOf()}',
    // Not zero, and not up to date. The two are the same number and different sentences.
    'NEVER_CHECKED' => 'Never checked against the upstream',
    'NO_UPSTREAM' => 'No upstream to fall behind',
    'OFFLINE' => 'Not checked: this project reaches nothing',
    'FAILED' => detail.isEmpty ? 'The last check did not work' : 'The last check did not work: $detail',
    // Added after this build shipped. Rendered, never thrown on.
    '' => 'Nothing said how far behind it is',
    _ => reason.toLowerCase().replaceAll('_', ' '),
  };
}

/// How far this account has got following a project's repository.
///
/// **What is in force and what was turned away are two fields**, because a screen asks both: a
/// project whose newest commit was refused goes on running what it had.
class Followed {
  /// The project's name.
  final String name;

  /// Where its repository is. Not a secret.
  final String url;

  /// The commit verified and in force, or empty when none ever was.
  final String commit;

  /// When it last tried, RFC 3339, or empty.
  final String at;

  /// Why it is where it is. Not an enum: new values may appear, and one this build does not know
  /// is rendered rather than thrown on.
  final String outcome;

  /// The commit turned away, or empty. Never the same field as [commit].
  final String refused;

  /// The fingerprint of the key that signed [refused], or empty. Only a fingerprint: not a secret.
  final String signer;

  /// The daemon's own words about it. Never parsed.
  final String detail;

  /// Whether nothing changes until somebody acts. **The daemon's answer, never worked out here**:
  /// an unreachable repository may answer on the next pass by itself, a refused signature never
  /// will, and which is which is the daemon's knowledge.
  final bool needsAPerson;

  /// What to type on that machine to store the credential a follow needs, with `NO_CREDENTIAL`; empty
  /// otherwise. On a follow's answer only.
  final String storeCommand;

  /// Whether the follow wrote anything: false for a check, and for a first follow that was refused —
  /// nothing of that project is on the machine then. On a follow's answer only.
  final bool recorded;

  /// Whether it is followed with no key pinned, so whoever can push to its repository decides
  /// what this machine runs. A state beside [outcome], never one of its values: a project can be
  /// unverified and unreachable at once.
  final bool unverified;

  /// With `UNKNOWN_HOST_KEY` and `HOST_KEY_CHANGED`, the host those keys belong to, as the machine
  /// names it — passed back to `TrustHostKey` unchanged, never worked out here from the URL.
  final String host;

  /// With those two outcomes, every key the host offers right now; empty otherwise.
  final List<HostKey> hostKeys;

  /// Constructor taking every field.
  const Followed({
    this.host = '',
    this.hostKeys = const <HostKey>[],
    required this.name,
    this.url = '',
    this.commit = '',
    this.at = '',
    this.outcome = '',
    this.refused = '',
    this.signer = '',
    this.detail = '',
    this.needsAPerson = false,
    this.unverified = false,
    this.storeCommand = '',
    this.recorded = false,
    this.signers = const <String>[],
    this.pinned = const <String>[],
  });

  /// Every key pinned for the project, by fingerprint: a commit signed by any of them is accepted.
  final List<String> signers;

  /// The fingerprints this follow pinned, or with a dry run would pin.
  final List<String> pinned;

  /// Reads one from a reply.
  factory Followed.from(Map<String, dynamic> map) => Followed(
    name: _string(map, 'name'),
    url: _string(map, 'url'),
    commit: _string(map, 'commit'),
    at: _string(map, 'at'),
    outcome: _string(map, 'outcome'),
    refused: _string(map, 'refused'),
    signer: _string(map, 'signer'),
    detail: _string(map, 'detail'),
    needsAPerson: map['needsAPerson'] == true,
    unverified: map['unverified'] == true,
    storeCommand: _string(map, 'storeCommand'),
    recorded: map['recorded'] == true,
    signers: map['signers'] is List ? <String>[for (final each in map['signers'] as List) '$each'] : const <String>[],
    pinned: map['pinned'] is List ? <String>[for (final each in map['pinned'] as List) '$each'] : const <String>[],
    host: _string(map, 'host'),
    hostKeys: map['hostKeys'] is List
        ? (map['hostKeys'] as List).whereType<Map<String, dynamic>>().map(HostKey.from).toList()
        : const <HostKey>[],
  );

  /// A project's `following`, or null when it follows nothing: absent, or an empty object — the
  /// contract has said both, and neither is a follow.
  static Followed? of(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final followed = Followed.from(value);
    final nothing = followed.name.isEmpty && followed.url.isEmpty && followed.outcome.isEmpty;
    return nothing ? null : followed;
  }

  /// Whether the newest commit it checked is the one in force.
  bool get inForce => outcome == 'APPLIED' || outcome == 'UNCHANGED';

  /// What its state is, in one line: the reason first, then what is still running.
  String get words {
    final turnedAway = refused.isEmpty ? 'the newest commit' : 'commit ${_short(refused)}';
    final why = switch (outcome) {
      'APPLIED' || 'UNCHANGED' => commit.isEmpty ? 'Following' : 'Following, at ${_short(commit)}',
      'NOT_SIGNED' => 'Not taken: $turnedAway is not signed',
      'UNKNOWN_KEY' => 'Not taken: $turnedAway is signed by a key this machine was never given',
      'NO_ANCHOR' => 'Not taken: no key is pinned here, so nothing can be verified',
      'UNREADABLE' => 'Not taken: the commit or the repository could not be read',
      'REWRITTEN' => 'Not taken: $turnedAway rewrites the history in force',
      'UNREACHABLE' => 'The repository cannot be reached',
      'NO_CREDENTIAL' => 'Not taken: the machine says nothing it holds reaches the repository',
      'UNUSABLE_VALUE' => 'Not taken: the credential for it is there, and cannot be used',
      'UNKNOWN_HOST_KEY' => 'Not taken: this machine has never met that host, and trusts no key of it yet',
      // Never "trust this instead": a key that changed may be somebody in between.
      'HOST_KEY_CHANGED' =>
        'Not taken: the host offered a different key from the one this machine remembers — this can '
            'be somebody in between',
      'VAULT_LOCKED' => "This account's store is shut, and the repository needs a credential from it",
      'UNUSABLE' => 'Not taken: the project file in $turnedAway does not read as a project',
      'FAILED' => 'The last attempt did not work',
      '' => 'Followed, and not tried yet',
      _ => outcome.toLowerCase().replaceAll('_', ' '),
    };
    final still = !inForce && commit.isNotEmpty ? ' · still running ${_short(commit)}' : '';
    return '$why$still';
  }

  static String _short(String commit) => commit.length > 7 ? commit.substring(0, 7) : commit;
}

/// What a task on one repository may consume, and which block each key came from.
///
/// **A repository's limits replace the project's key by key**, so the part worth saying is which
/// key a repository replaced. `"project"` covers both a value the project file wrote and Porelo's own
/// default, which nothing can tell apart — so it is never worded as somebody having set it.
class ResolvedLimits {
  /// Memory limit, or empty for none.
  final String memory;

  /// CPU limit, or empty for none.
  final String cpus;

  /// Process limit. Always set.
  final int pids;

  /// `repository` or `project`, for each key.
  final String memoryFrom;

  /// See [memoryFrom].
  final String cpusFrom;

  /// See [memoryFrom].
  final String pidsFrom;

  /// Constructor taking every field.
  const ResolvedLimits({
    this.memory = '',
    this.cpus = '',
    this.pids = 0,
    this.memoryFrom = '',
    this.cpusFrom = '',
    this.pidsFrom = '',
  });

  /// Reads one from a reply.
  factory ResolvedLimits.from(Map<String, dynamic> map) => ResolvedLimits(
    memory: _string(map, 'memory'),
    cpus: _string(map, 'cpus'),
    pids: _int(map, 'pids'),
    memoryFrom: _string(map, 'memoryFrom'),
    cpusFrom: _string(map, 'cpusFrom'),
    pidsFrom: _string(map, 'pidsFrom'),
  );

  /// All three in one line, the ones the repository replaced marked as its own.
  String get words {
    String one(String what, String value, String from) =>
        '$what ${value.isEmpty ? 'no limit' : value}${from == 'repository' ? ' (its own)' : ''}';
    return <String>[
      one('memory', memory, memoryFrom),
      one('cpus', cpus, cpusFrom),
      one('processes', '$pids', pidsFrom),
    ].join(' · ');
  }

  /// Whether the repository replaced any of the project's keys.
  bool get anyOfItsOwn => memoryFrom == 'repository' || cpusFrom == 'repository' || pidsFrom == 'repository';
}

/// One credential a machine may use to reach somewhere, described without its secret.
///
/// **The description is not secret**, so it may be written over the socket; the value never is.
class Connection {
  /// What the secret is called: a vault entry, a file path or a variable, by [source].
  final String id;

  /// `SSH_KEY`, `TOKEN`, `BASIC` or `OAUTH`. Said, never inferred from an address.
  final String kind;

  /// The destinations it covers, as a prefix of the normalized address. The longest match wins.
  final String match;

  /// A username, for `BASIC` and a token that needs one; empty when the default is fine.
  final String user;

  /// What it may be used for: `git`, `registry`, … or `any`.
  final String purpose;

  /// `VAULT`, `FILE`, `ENVIRONMENT` or `AGENT`.
  final String source;

  /// Whether the secret is somewhere the machine encrypts and can shut. **Shown, never refused.**
  final bool protected;

  /// Whether the secret is there right now. With a shut vault this only says the vault is shut.
  final bool present;

  /// When an OAuth token stops working, RFC 3339, or empty.
  final String expires;

  /// Constructor taking every field.
  const Connection({
    this.id = '',
    this.kind = '',
    this.match = '',
    this.user = '',
    this.purpose = '',
    this.source = '',
    this.protected = false,
    this.present = false,
    this.expires = '',
  });

  /// Reads one from a reply.
  factory Connection.from(Map<String, dynamic> map) => Connection(
    id: _string(map, 'id'),
    kind: _string(map, 'kind'),
    match: _string(map, 'match'),
    user: _string(map, 'user'),
    purpose: _string(map, 'purpose'),
    source: _string(map, 'source'),
    protected: map['protected'] == true,
    present: map['present'] == true,
    expires: _string(map, 'expires'),
  );

  /// The kind, for a person.
  String get kindWords => switch (kind) {
    'SSH_KEY' => 'an ssh key',
    'TOKEN' => 'a token',
    'BASIC' => 'a user and password',
    'OAUTH' => 'an OAuth token',
    _ => kind.toLowerCase().replaceAll('_', ' '),
  };

  /// Where the value is, for a person.
  String get sourceWords => switch (source) {
    'VAULT' => 'in the vault as $id',
    'FILE' => 'in the file $id',
    'ENVIRONMENT' => 'in the variable $id',
    'AGENT' => "from the account's own ssh agent",
    _ => source.toLowerCase(),
  };
}

/// What declaring a connection wrote, and how its value is stored.
class CredentialDeclared {
  /// The record as it was written, its address normalized.
  final Connection connection;

  /// What to run on that machine to store the value, as arguments; empty when there is nothing to
  /// store because the value is already somewhere.
  final List<String> storeCommand;

  /// What that command needs on its standard input, in words, or empty when it asks for the value
  /// itself. An ssh key is a file and cannot be typed at a prompt.
  final String storeStdin;

  /// Whether it replaced a record for the same address and purpose — *updated* rather than *added*.
  final bool replaced;

  /// Whether anything was written: false for a dry run.
  final bool recorded;

  /// For a dry run, `READY` or why it would not work; empty for a real declaration. Not an enum.
  final String outcome;

  /// For a dry run of an ssh key, who the forge says the key logs in as, or empty. The machine's words.
  final String identity;

  /// For a dry run, one sentence for a person. The machine's; never parsed.
  final String detail;

  /// Constructor taking every field.
  const CredentialDeclared({
    required this.connection,
    this.storeCommand = const <String>[],
    this.storeStdin = '',
    this.replaced = false,
    this.recorded = false,
    this.outcome = '',
    this.identity = '',
    this.detail = '',
  });

  /// Whether a dry run leaves nothing in the way of adding it: ready, or a value still to be stored
  /// by the command it names — which is what the step after adding does.
  bool get canBeAdded => outcome == 'READY' || (outcome == 'MISSING_VALUE' && storeCommand.isNotEmpty);

  /// Reads one from a reply.
  factory CredentialDeclared.from(Map<String, dynamic> map) => CredentialDeclared(
    connection: map['connection'] is Map<String, dynamic>
        ? Connection.from(map['connection']! as Map<String, dynamic>)
        : const Connection(),
    storeCommand: _strings(map, 'storeCommand'),
    storeStdin: _string(map, 'storeStdin'),
    replaced: map['replaced'] == true,
    recorded: map['recorded'] == true,
    outcome: _string(map, 'outcome'),
    identity: _string(map, 'identity'),
    detail: _string(map, 'detail'),
  );
}

/// What forgetting a connection did. **The secret is not removed.**
class CredentialForgotten {
  /// Whether there was a record to forget.
  final bool forgotten;

  /// What still holds a value, or empty — so the second step is offered, not implied done.
  final String leftBehind;

  /// Constructor taking every field.
  const CredentialForgotten({required this.forgotten, this.leftBehind = ''});

  /// Reads one from a reply.
  factory CredentialForgotten.from(Map<String, dynamic> map) =>
      CredentialForgotten(forgotten: map['forgotten'] == true, leftBehind: _string(map, 'leftBehind'));
}

/// One key a host offers: what a person compares with what they were told, out of band.
class HostKey {
  /// Its algorithm, as ssh names it.
  final String type;

  /// `SHA256:…`, the form ssh prints and the form a host publishes.
  final String fingerprint;

  /// Constructor taking every field.
  const HostKey({this.type = '', this.fingerprint = ''});

  /// Reads one from a reply.
  factory HostKey.from(Map<String, dynamic> map) =>
      HostKey(type: _string(map, 'type'), fingerprint: _string(map, 'fingerprint'));
}

/// What trusting a host key did: recorded only if the host still offered the key a person confirmed.
class HostKeyTrusted {
  /// Whether it was written down.
  final bool recorded;

  /// The type of the key that was recorded, or empty.
  final String type;

  /// The fingerprint of the key that was recorded, or empty.
  final String fingerprint;

  /// The machine's own words. Never parsed.
  final String detail;

  /// Constructor taking every field.
  const HostKeyTrusted({this.recorded = false, this.type = '', this.fingerprint = '', this.detail = ''});

  /// Reads one from a reply.
  factory HostKeyTrusted.from(Map<String, dynamic> map) => HostKeyTrusted(
    recorded: map['recorded'] == true,
    type: _string(map, 'type'),
    fingerprint: _string(map, 'fingerprint'),
    detail: _string(map, 'detail'),
  );
}

/// An ssh key the machine's account already has, described without its value.
///
/// **The machine decides what is a key**: telling a private key from its public half takes reading
/// the file, and the file stays there.
class SshKey {
  /// Where it is on the machine.
  final String path;

  /// Its algorithm, as ssh names it: `ssh-ed25519`, `ssh-rsa`, ….
  final String type;

  /// Its `SHA256:` fingerprint.
  final String fingerprint;

  /// The comment of its public half, often who it belongs to; empty when there is none.
  final String comment;

  /// Whether a passphrase protects it, which nothing on the machine can ask for.
  final bool encrypted;

  /// Whether the private file is there; without it the key cannot sign anything.
  final bool privateHalf;

  /// Whether the machine itself can sign with it. One it cannot may still serve ssh where it lies.
  final bool usable;

  /// `DIRECTORY` or `CONFIGURED` — an `IdentityFile` in `~/.ssh/config` named it. Not an enum.
  final String found;

  /// What stands in the way of using it, and what to do, in the machine's words; empty when nothing.
  final String obstacle;

  /// Constructor taking every field.
  const SshKey({
    required this.path,
    this.type = '',
    this.fingerprint = '',
    this.comment = '',
    this.encrypted = false,
    this.privateHalf = false,
    this.usable = false,
    this.found = '',
    this.obstacle = '',
  });

  /// Reads one from a reply.
  factory SshKey.from(Map<String, dynamic> map) => SshKey(
    path: _string(map, 'path'),
    type: _string(map, 'type'),
    fingerprint: _string(map, 'fingerprint'),
    comment: _string(map, 'comment'),
    encrypted: map['encrypted'] == true,
    privateHalf: map['privateHalf'] == true,
    usable: map['usable'] == true,
    found: _string(map, 'found'),
    obstacle: _string(map, 'obstacle'),
  );

  /// Whether it can be named as a key kept where it lies: ssh signs with the private file itself.
  bool get servesWhereItLies => privateHalf;
}

/// Which credential a destination would use, and whether it would work — asked before anything is
/// tried, without touching the network.
class CredentialChecked {
  /// `READY`, `NO_CREDENTIAL`, `VAULT_LOCKED`, `MISSING_VALUE`, `EXPIRED` or `NOT_NEEDED`. Not an enum:
  /// a value added later is rendered, never thrown on.
  final String outcome;

  /// The record that would be used, or an empty one.
  final Connection connection;

  /// What to run on that machine to fix it, as arguments; empty when nothing here would help.
  final List<String> storeCommand;

  /// What that command needs on its standard input, or empty.
  final String storeStdin;

  /// One sentence for a person. The daemon's; never parsed.
  final String detail;

  /// Constructor taking every field.
  const CredentialChecked({
    required this.outcome,
    this.connection = const Connection(),
    this.storeCommand = const <String>[],
    this.storeStdin = '',
    this.detail = '',
  });

  /// Reads one from a reply.
  factory CredentialChecked.from(Map<String, dynamic> map) => CredentialChecked(
    outcome: _string(map, 'outcome'),
    connection: map['connection'] is Map<String, dynamic>
        ? Connection.from(map['connection']! as Map<String, dynamic>)
        : const Connection(),
    storeCommand: _strings(map, 'storeCommand'),
    storeStdin: _string(map, 'storeStdin'),
    detail: _string(map, 'detail'),
  );

  /// Whether nothing stands in the way — including a local path, which needs nothing.
  bool get clear => outcome == 'READY' || outcome == 'NOT_NEEDED';
}

/// One message a person is asked to decide about, as `Held` lists it: **never its text**, which is
/// read on its own with `ReadHeld` when somebody opens it.
class HeldMessage {
  /// Container name of the task whose mailbox it is in.
  final String task;

  /// held, refused-by-filter, refused-by-person or unchecked. A plain string: a standing this build
  /// has not heard of is shown, not dropped.
  final String standing;

  /// Its file name.
  final String message;

  /// Its message id, or empty when none could be read.
  final String id;

  /// ROLE_USER when a person wrote it, ROLE_AGENT when a task did, or empty.
  final String role;

  /// The peer it was going to or came from, or empty.
  final String peer;

  /// question, answer, status, review-request or handover, or empty.
  final String kind;

  /// When the host first recorded it, RFC 3339, or empty.
  final String at;

  /// Why it is held, or for a refused one the filter's own answer.
  final String reason;

  /// out when it was leaving, in when it arrived from a peer, or empty from a daemon older than the
  /// field, which says nothing either way.
  final String direction;

  /// Constructor taking every field.
  const HeldMessage({
    required this.task,
    required this.standing,
    required this.message,
    required this.id,
    required this.role,
    required this.peer,
    required this.kind,
    required this.at,
    required this.reason,
    this.direction = '',
  });

  /// Reads one from a reply.
  factory HeldMessage.from(Map<String, dynamic> map) => HeldMessage(
    task: _string(map, 'task'),
    standing: _string(map, 'standing'),
    message: _string(map, 'message'),
    id: _string(map, 'id'),
    role: _string(map, 'role'),
    peer: _string(map, 'peer'),
    kind: _string(map, 'kind'),
    at: _string(map, 'at'),
    reason: _string(map, 'reason'),
    direction: _string(map, 'direction'),
  );

  /// Whether a person still has something to decide: held, or refused by the filter and so still
  /// deliverable after all. What a person refused for good, or the filter could not check, is only
  /// listed because it is still there.
  bool get waits => standing == 'held' || standing == 'refused-by-filter';

  /// How to name it to the machine: the file, which is what was listed, never a guess.
  String get handle => message.isNotEmpty ? message : id;
}

/// One message read in full with `ReadHeld`, so a person decides about what it says.
class HeldMessageRead {
  /// FOUND, NO_SUCH_MESSAGE or AMBIGUOUS.
  final String outcome;

  /// As [HeldMessage.standing], or empty when it was not found.
  final String standing;

  /// Its file name, which the decision names, so what was read is what is decided.
  final String message;

  /// Its message id, or empty.
  final String id;

  /// ROLE_USER, ROLE_AGENT, or empty.
  final String role;

  /// The peer, or empty.
  final String peer;

  /// Its kind, or empty.
  final String kind;

  /// When it was first recorded, or empty.
  final String at;

  /// Its parts in order, exactly as written. **Shown as text and never interpreted**: no markup, no
  /// link, nothing fetched.
  final List<String> text;

  /// Why it is held, or the filter's own answer.
  final String reason;

  /// out, in, or empty, as [HeldMessage.direction].
  final String direction;

  /// Constructor taking every field.
  const HeldMessageRead({
    required this.outcome,
    required this.standing,
    required this.message,
    required this.id,
    required this.role,
    required this.peer,
    required this.kind,
    required this.at,
    required this.text,
    required this.reason,
    this.direction = '',
  });

  /// Reads one from a reply.
  factory HeldMessageRead.from(Map<String, dynamic> map) => HeldMessageRead(
    outcome: _string(map, 'outcome'),
    standing: _string(map, 'standing'),
    message: _string(map, 'message'),
    id: _string(map, 'id'),
    role: _string(map, 'role'),
    peer: _string(map, 'peer'),
    kind: _string(map, 'kind'),
    at: _string(map, 'at'),
    text: _strings(map, 'text'),
    reason: _string(map, 'reason'),
    direction: _string(map, 'direction'),
  );

  /// Whether it was there to read.
  bool get found => outcome == 'FOUND';
}

/// What `Release` did with one message.
class MessageRelease {
  /// RELEASED, REFUSED, DELIVERED_DESPITE_FILTER, NOT_DELIVERABLE, NO_SUCH_MESSAGE or AMBIGUOUS.
  final String outcome;

  /// The file it acted on, or empty.
  final String message;

  /// The message id, or empty.
  final String id;

  /// Why, for NOT_DELIVERABLE.
  final String detail;

  /// Constructor taking every field.
  const MessageRelease({required this.outcome, required this.message, required this.id, required this.detail});

  /// Reads one from a reply.
  factory MessageRelease.from(Map<String, dynamic> map) => MessageRelease(
    outcome: _string(map, 'outcome'),
    message: _string(map, 'message'),
    id: _string(map, 'id'),
    detail: _string(map, 'detail'),
  );
}

/// Something that happened to a message in one mailbox, as `Talk` streams it. **Never what the
/// message said.**
class TalkEvent {
  /// Container name of the task whose mailbox it is about.
  final String task;

  /// When, RFC 3339.
  final String at;

  /// taken, queued, sent, deferred, held, delivered, duplicate, refused or overridden.
  final String event;

  /// The message's file name.
  final String message;

  /// Its id, or empty.
  final String id;

  /// The peer, or empty.
  final String peer;

  /// Why, for the events that have a why.
  final String detail;

  /// Constructor taking every field.
  const TalkEvent({
    required this.task,
    required this.at,
    required this.event,
    required this.message,
    required this.id,
    required this.peer,
    required this.detail,
  });

  /// Reads one from a reply.
  factory TalkEvent.from(Map<String, dynamic> map) => TalkEvent(
    task: _string(map, 'task'),
    at: _string(map, 'at'),
    event: _string(map, 'event'),
    message: _string(map, 'message'),
    id: _string(map, 'id'),
    peer: _string(map, 'peer'),
    detail: _string(map, 'detail'),
  );
}

/// One peer a task may address, and what a person decided about it, as `Peers` answers.
class TalkPeer {
  /// What a message addresses.
  final String name;

  /// `<transport>:<rest>`.
  final String address;

  /// vouched or external: whether what arrives from it is checked again here.
  final String trust;

  /// How many messages a day this task may exchange with it, each way.
  final int perDay;

  /// prompt, allow, deny or off. A plain string: a mode this build has not heard of is shown.
  final String mode;

  /// Whether everything for this peer waits, whatever the mode says.
  final bool held;

  /// How many went to it today, or null from a daemon that does not say.
  final int? sentToday;

  /// How many came from it today, or null from a daemon that does not say.
  final int? receivedToday;

  /// Constructor taking every field.
  const TalkPeer({
    required this.name,
    required this.address,
    required this.trust,
    required this.perDay,
    required this.mode,
    required this.held,
    this.sentToday,
    this.receivedToday,
  });

  /// Reads one from a reply.
  factory TalkPeer.from(Map<String, dynamic> map) => TalkPeer(
    name: _string(map, 'name'),
    address: _string(map, 'address'),
    trust: _string(map, 'trust'),
    perDay: _int(map, 'perDay'),
    mode: _string(map, 'mode'),
    held: map['held'] == true,
    // Absent is not zero: an older daemon cannot say, and zero would claim nothing was used.
    sentToday: map['sentToday'] is num ? (map['sentToday'] as num).toInt() : null,
    receivedToday: map['receivedToday'] is num ? (map['receivedToday'] as num).toInt() : null,
  );

  /// Whether a message to it goes without a person reading it first. Never while it is held.
  bool get reachable => !held && (mode == 'allow' || mode == 'off');
}

/// What `Say` did: written into the outbox, never yet *sent*.
class Said {
  /// The file written into the outbox.
  final String message;

  /// WRITTEN.
  final String outcome;

  /// Constructor taking every field.
  const Said({required this.message, required this.outcome});

  /// Reads one from a reply.
  factory Said.from(Map<String, dynamic> map) =>
      Said(message: _string(map, 'message'), outcome: _string(map, 'outcome'));
}

/// One file a push changes, ranked by the machine for the review.
///
/// **The rank and its reason are the machine's**, from a list fixed in Porelo: nothing here
/// re-ranks, re-classifies or extends it.
class ReviewFile {
  /// Its path.
  final String path;

  /// A, M, D or T.
  final String status;

  /// Lines added.
  final int added;

  /// Lines removed; -1 for a binary file.
  final int removed;

  /// DANGEROUS, ORDINARY, GENERATED or REFORMATTING, as a plain string: one this build has not heard
  /// of is shown as the machine said it.
  final String rank;

  /// Why it is ranked so, in the machine's words, e.g. which kind of dangerous file it is.
  final String reason;

  /// Constructor taking every field.
  const ReviewFile({
    required this.path,
    required this.status,
    required this.added,
    required this.removed,
    required this.rank,
    required this.reason,
  });

  /// Reads one from a reply.
  factory ReviewFile.from(Map<String, dynamic> map) => ReviewFile(
    path: _string(map, 'path'),
    status: _string(map, 'status'),
    added: _int(map, 'added'),
    removed: map['removed'] is num ? (map['removed'] as num).toInt() : 0,
    rank: _string(map, 'rank'),
    reason: _string(map, 'reason'),
  );

  /// Whether it is dangerous by kind: named first, however small its change.
  bool get dangerous => rank == 'DANGEROUS';

  /// Whether it is the volume that is almost never a finding: generated, or reformatting only.
  bool get volume => rank == 'GENERATED' || rank == 'REFORMATTING';
}

/// A service a credential is for that is not a model provider: where it is, and where its key goes.
class Destination {
  /// Its name, which a credential is given for.
  final String name;

  /// What to call it.
  final String label;

  /// Where requests go, https.
  final String upstream;

  /// The header the key goes in, and the text before it.
  final String authHeader;

  /// The text before the key in [authHeader], such as `Bearer `.
  final String authPrefix;

  /// The URL parameter the key goes in instead, or empty for the header.
  final String authQuery;

  /// The file that declares it, on the machine.
  final String file;

  /// Whether a package installed it: it cannot be changed or removed here, only put in the place of.
  final bool packaged;

  /// Whether it is the one in force for its name.
  final bool inForce;

  /// Constructor taking every field.
  const Destination({
    required this.name,
    required this.label,
    required this.upstream,
    required this.authHeader,
    required this.authPrefix,
    required this.authQuery,
    required this.file,
    required this.packaged,
    required this.inForce,
  });

  /// Reads one from a reply.
  factory Destination.from(Map<String, dynamic> map) => Destination(
    name: _string(map, 'name'),
    label: _string(map, 'label'),
    upstream: _string(map, 'upstream'),
    authHeader: _string(map, 'authHeader'),
    authPrefix: _string(map, 'authPrefix'),
    authQuery: _string(map, 'authQuery'),
    file: _string(map, 'file'),
    packaged: map['packaged'] == true,
    inForce: map['inForce'] == true,
  );

  /// Where the key goes, in words.
  String get keyGoes => authQuery.isNotEmpty
      ? 'in the URL parameter $authQuery'
      : 'in the header $authHeader${authPrefix.isEmpty ? '' : ', after "$authPrefix"'}';
}

/// One thing `Clear` removed, would remove, could not, or leaves to a person.
class ClearedItem {
  /// Constructor taking every field.
  const ClearedItem({required this.kind, required this.what, required this.status, this.why = ''});

  /// What sort of thing it is, as the machine names it (`TASK`, `WORKSPACE`, `FOLLOW`, `HOMESERVER`…).
  final String kind;

  /// Which one, in the machine's words.
  final String what;

  /// `REMOVED`, `WOULD_REMOVE`, `NOT_REMOVED` or `FOR_A_PERSON`.
  final String status;

  /// Why, where it was not removed or is left to a person.
  final String why;

  /// Reads one from a reply.
  factory ClearedItem.from(Map<String, dynamic> map) => ClearedItem(
    kind: _string(map, 'kind'),
    what: _string(map, 'what'),
    status: _string(map, 'status'),
    why: _string(map, 'why'),
  );
}

/// What `Clear` answered: what it did, or with a dry run would do, on the machine, and what only the
/// person's credentials remove at the forge.
class Cleared {
  /// Constructor taking every field.
  const Cleared({
    this.items = const <ClearedItem>[],
    this.keys = const <MachineDeployKey>[],
    this.signer = '',
    this.refused = false,
  });

  /// Each thing, in the order it was done.
  final List<ClearedItem> items;

  /// The machine's deploy keys for the projects cleared, to be removed at the forge.
  final List<MachineDeployKey> keys;

  /// The machine's `machine-signers` line, to be taken out of each project's file; empty for none.
  final String signer;

  /// Stopped before removing anything: unreviewed work, or a task running. `force` clears them too.
  final bool refused;

  /// Reads one from a reply.
  factory Cleared.from(Map<String, dynamic> map) => Cleared(
    items: <ClearedItem>[
      if (map['items'] case final List<dynamic> items)
        for (final each in items)
          if (each is Map<String, dynamic>) ClearedItem.from(each),
    ],
    keys: <MachineDeployKey>[
      if (map['keys'] case final List<dynamic> keys)
        for (final each in keys)
          if (each is Map<String, dynamic>) MachineDeployKey.from(each),
    ],
    signer: _string(map, 'signer'),
    refused: map['refused'] == true,
  );
}
