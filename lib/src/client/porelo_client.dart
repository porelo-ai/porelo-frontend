import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../wire/varlink_connection.dart';
import '../wire/varlink_exception.dart';
import 'host_identity.dart';
import 'models.dart';
import 'environment.dart';
import '../wire/limit_factors.dart';

/// A relay ended before the daemon answered, retaining the transport's own verdict.
class RelayDisconnected extends VarlinkDisconnected {
  /// Constructor taking the bounded diagnostic and exit status, if it arrived in time.
  const RelayDisconnected(super.message, this.exitCode);

  /// The relay's exit status, or null when it did not exit within the diagnostic deadline.
  final int? exitCode;
}

/// What a connection through a relay is for, which decides the place it waits for.
class RelayUse {
  /// A single call, answered within its deadline.
  const RelayUse.call() : watch = null, long = false, follows = false;

  /// A stream, or a call that may wait long: it has no deadline to free its place by.
  const RelayUse.stream() : watch = null, long = true, follows = false;

  /// The watch [method], which holds a place of its own for as long as it runs.
  const RelayUse.watch(String method) : watch = method, long = true, follows = false;

  /// A stream without end that follows one thing among many, such as a log or a project's pull requests: it holds a
  /// place of its own while it runs, so a call never waits behind it.
  const RelayUse.follow() : watch = null, long = true, follows = true;

  /// The watch's method, or null for any other connection.
  final String? watch;

  /// Whether it follows one thing among many, without end.
  final bool follows;

  /// Whether it may hold its place without end.
  final bool long;
}

/// A place a relay's process holds while it runs.
abstract interface class RelayPlace {
  /// Gives the place back; only the first call counts.
  void leave();
}

/// Admits the processes of one relay, each to a place of its own, in turn.
abstract interface class RelayAdmission {
  /// Waits for a place for [use], or answers null once [abandoned] completed before one was given.
  Future<RelayPlace?> enter(RelayUse use, {Future<void>? abandoned});
}

/// Starts a relay's process, for a test to stand in.
typedef StartRelay = Future<Process> Function(String executable, List<String> arguments);

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

  /// Admits each process of [relay] to a place, or null where they are not bounded here.
  final RelayAdmission? admission;

  /// How a process of [relay] is started.
  final StartRelay startRelay;

  /// Constructor with the socket and how to name it.
  const Backend({
    required this.socketPath,
    required this.label,
    this.notReachable,
    this.relay,
    this.whyNotNow,
    this.admission,
    this.startRelay = Process.start,
  });

  /// Opens a connection to it for [use], or says in [notReachable]'s words why there is none.
  ///
  /// Through a relay with an [admission], it first waits for a place, which is given back once the relay's process
  /// exited; once [abandoned] completes, a wait still under way ends, and nothing is started.
  Future<VarlinkConnection> open({RelayUse use = const RelayUse.call(), Future<void>? abandoned}) async {
    final why = notReachable;
    if (why != null) throw VarlinkDisconnected(why);
    final through = relay;
    if (through == null) return VarlinkConnection.open(socketPath);
    final notNow = await whyNotNow?.call();
    if (notNow != null) throw VarlinkDisconnected(notNow);
    final RelayPlace? place;
    if (admission case final admission?) {
      var gone = false;
      unawaited(abandoned?.then<void>((_) => gone = true, onError: (Object _) => gone = true));
      place = await admission.enter(use, abandoned: abandoned);
      if (place == null) throw VarlinkDisconnected('The connection to $label was no longer wanted.');
      // Left before its place came: nothing is started for it.
      if (gone) {
        place.leave();
        throw VarlinkDisconnected('The connection to $label was no longer wanted.');
      }
    } else {
      place = null;
    }
    final Process process;
    try {
      process = await startRelay(through.first, through.sublist(1));
    } on ProcessException catch (failed) {
      place?.leave();
      throw VarlinkDisconnected('`${through.first}` could not be started: ${failed.message}');
    } on Object {
      place?.leave();
      rethrow;
    }
    var exited = false;
    // Its place is free only once it exited.
    unawaited(
      process.exitCode.then<void>(
        (_) {
          exited = true;
          place?.leave();
        },
        onError: (Object _) {
          exited = true;
          place?.leave();
        },
      ),
    );
    void end() {
      process.kill();
      // One that does not end when asked would keep its place for good.
      if (place != null) {
        Timer(machineWait(const Duration(seconds: 2)), () => exited || process.kill(ProcessSignal.sigkill));
      }
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

    return VarlinkConnection.over(incoming: incoming(), outgoing: process.stdin, destroy: end, writeFailure: ended);
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

/// The machine could not start a sign-in of [agent], and says why: [reason] (`NO_SUCH_AGENT`, `UNSUPPORTED`,
/// `LOOPBACK_OVER_SSH`, `NO_CONFIG_DIRECTORY`, `ALREADY_SIGNED_IN`, `VAULT_LOCKED`, `FAILED`, or one this build does
/// not know), and [detail] in words, shown as it comes.
class SignInRefused extends VarlinkException {
  /// Constructor taking the refusal as it came.
  SignInRefused(VarlinkException refusal)
    : agent = '${refusal.parameters['agent'] ?? ''}',
      reason = '${refusal.parameters['reason'] ?? ''}',
      detail = '${refusal.parameters['detail'] ?? ''}',
      super(refusal.name, refusal.parameters);

  /// The agent it was asked to sign in.
  final String agent;

  /// Why not, as the machine names it; empty where it gave none.
  final String reason;

  /// Why not, in the machine's words; empty where it gave none.
  final String detail;
}

/// The machine holds no forge token of the person's for its host's forge, under the entry its own command writes:
/// [storeCommand] is that command, run on the machine by the person, never from here.
class MissingHostForgeToken extends VarlinkException {
  /// Constructor taking the refusal as it came.
  MissingHostForgeToken(VarlinkException refusal)
    : credential = '${refusal.parameters['credential'] ?? ''}',
      storeCommand = MissingCredential.plainWords(refusal.parameters['storeCommand']),
      super(refusal.name, refusal.parameters);

  /// The vault entry it looked for; a name, never a value.
  final String credential;

  /// The command that stores it, as its arguments; empty where the machine named none, or named one with a word
  /// that is no text, is empty, or holds a control or line separator: such a command is never offered to copy.
  final List<String> storeCommand;
}

/// The machine would not read its host forge's pull requests, and says why: [reason] (`settings`,
/// `vault-unreadable`, `not-carried`, `forge-token`, `forge`, `forge-answer`, `makers`, `bounds`, or one this build
/// does not know), and [message] in words, shown as it comes.
class HostPullRequestsRefused extends VarlinkException {
  /// Constructor taking the refusal as it came.
  HostPullRequestsRefused(VarlinkException refusal)
    : reason = '${refusal.parameters['reason'] ?? ''}',
      message = '${refusal.parameters['message'] ?? ''}',
      super(refusal.name, refusal.parameters);

  /// [refusal] as what it says, where it is one of the two a host forge's pull requests are refused with.
  static Object typed(Object refusal) => switch (refusal) {
    VarlinkException(simpleName: 'MissingHostForgeToken') => MissingHostForgeToken(refusal),
    VarlinkException(simpleName: 'HostPullRequestsRefused') => HostPullRequestsRefused(refusal),
    _ => refusal,
  };

  /// Why not, as the machine names it; empty where it gave none.
  final String reason;

  /// Why not, in the machine's words; empty where it gave none.
  final String message;
}

/// A pull request list the machine gave in pages that do not fit together, or never end: [what] says how. Its watch
/// ends with it, and it is not asked for again until the person asks or the machine is reached anew.
class PullRequestsPagingBroken implements Exception {
  /// Constructor taking the project and what did not fit.
  const PullRequestsPagingBroken(this.project, this.what);

  /// The project whose pull requests were read.
  final String project;

  /// What did not fit, in words.
  final String what;

  @override
  String toString() => 'PullRequestsPagingBroken($project): $what';
}

/// A reading no longer wanted: its watch was cancelled or ended meanwhile.
class _Overtaken implements Exception {
  const _Overtaken();
}

/// The machine did not bring a host's `main` to central, and says why, as one of the answers `PushToCentral` names:
/// [kind] is the answer's name (`CentralVaultShut`, `MissingCentralToken`, `CentralTokenRefused`, `NothingToPush`,
/// `HostPushTokenUnavailable`, `CentralPushRefused`, `CentralPushUncertain`, `HostPushRefused`), and each field is
/// what it carried, read leniently: a field of another type is left empty, never guessed.
class CentralPushRefusal extends VarlinkException {
  /// Constructor taking the refusal as it came.
  CentralPushRefusal(VarlinkException refusal)
    : kind = refusal.simpleName,
      unlock = _text(refusal.parameters['unlock']),
      unlockCommand = _command(refusal.parameters['unlockCommand']),
      credential = _text(refusal.parameters['credential']),
      storeCommand = _command(refusal.parameters['storeCommand']),
      repository = _text(refusal.parameters['repository']),
      reason = _text(refusal.parameters['reason']),
      branch = _text(refusal.parameters['branch']),
      forge = _text(refusal.parameters['forge']),
      status = switch (refusal.parameters['status']) {
        final int status => status,
        _ => null,
      },
      code = switch (refusal.parameters['code']) {
        final int code => code,
        _ => null,
      },
      pushed = _texts(refusal.parameters['pushed']),
      upToDate = _texts(refusal.parameters['upToDate']),
      super(refusal.name, refusal.parameters);

  /// The answers `PushToCentral` names; another refusal is passed on as it came.
  static const kinds = {
    'CentralVaultShut',
    'MissingCentralToken',
    'CentralTokenRefused',
    'NothingToPush',
    'HostPushTokenUnavailable',
    'CentralPushRefused',
    'CentralPushUncertain',
    'HostPushRefused',
  };

  /// [refusal] as what it says, where it is one of [kinds].
  static Object typed(Object refusal) =>
      refusal is VarlinkException && kinds.contains(refusal.simpleName) ? CentralPushRefusal(refusal) : refusal;

  /// The answer's name.
  final String kind;

  /// How the shut vault opens: `init`, `passphrase`, `host`, `device`, or a later word; empty where not said.
  final String unlock;

  /// The command that opens it, as arguments; empty for the enrolled device, or where a word could not be shown.
  final List<String> unlockCommand;

  /// The vault entry of the central token; a name, never a value.
  final String credential;

  /// The command that stores the central token, as arguments; empty where none is offered.
  final List<String> storeCommand;

  /// The forge repository it stopped at; empty where not said.
  final String repository;

  /// Why, as the machine names it; empty where not said.
  final String reason;

  /// Where central's own `main` was brought for a merge in a task; empty where it was not.
  final String branch;

  /// The central forge that refused the token; empty where not said.
  final String forge;

  /// The HTTP status the forge refused it with, where said.
  final int? status;

  /// The host command's exit code, where said.
  final int? code;

  /// The repositories confirmed pushed before it stopped.
  final List<String> pushed;

  /// The repositories confirmed already at central before it stopped.
  final List<String> upToDate;

  static final _unsafe = RegExp('[\\x00-\\x1f\\x7f-\\x9f\\u2028\\u2029]');

  static String _text(Object? value) => value is String && !_unsafe.hasMatch(value) ? value.trim() : '';

  static List<String> _texts(Object? value) => [
    if (value is List)
      for (final each in value)
        if (_text(each) case final text when text.isNotEmpty) text,
  ];

  static List<String> _command(Object? value) => switch (value) {
    final List<dynamic> words when words.isNotEmpty && words.every((word) => _text(word).isNotEmpty) =>
      words.cast<String>().toList(),
    _ => const <String>[],
  };
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

  PoreloClient._(this.backend, this.interfaceName, this.info, this.answerWithin, this.machine);

  /// The machine whose factors its calls' bounds follow; this computer's for null.
  final String? machine;

  /// Connects and agrees an interface.
  ///
  /// Throws [VarlinkDisconnected] when there is nothing there, and [StateError] when the backend
  /// serves no interface this build knows - which is a backend too new or too old to talk to at
  /// all, and is worth saying plainly rather than failing on the first call.
  static Future<PoreloClient> connect(
    Backend backend, {
    Duration answerWithin = VarlinkConnection.answerWithin,
    String? machine,
  }) async {
    final connection = await backend.open();
    try {
      // Shorter than the default: "is there a daemon on the other end of this socket" has to
      // answer quickly, or the window sits on an empty frame saying it is connecting.
      final info = ServiceInfo.from(
        await connection.call(
          'org.varlink.service.GetInfo',
          const {},
          serviceWait(const Duration(seconds: 5), machine: machine),
        ),
      );
      final agreed = supported.where(info.interfaces.contains);
      if (agreed.isEmpty) {
        throw StateError(
          '${backend.label} serves ${info.interfaces}, none of which this build understands '
          '(it knows $supported)',
        );
      }
      return PoreloClient._(backend, agreed.first, info, answerWithin, machine);
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
  Future<bool>? _startCertify;
  Future<bool>? _startFrom;
  final _startDeclared = <String, Future<bool>>{};

  /// Whether Start declares [input], asked once; a read that failed is forgotten, so the next ask reads again.
  Future<bool> _startDeclares(String input) async {
    final asked = _startDeclared[input] ??= _declaresStartInput(input);
    try {
      return await asked;
    } on Object {
      if (identical(_startDeclared[input], asked)) _startDeclared.remove(input);
      rethrow;
    }
  }

  Future<bool> _declaresStartSteps() => _declaresStartInput('steps');

  /// Why this machine's Porelo cannot start a discussion of an idea - every repository of a project read only - in
  /// words, or null where it can.
  Future<String?> whyNoDiscussion() async {
    if (!await _startDeclares('allRepositories')) {
      return "This machine's Porelo cannot read every repository of a project for a discussion; it needs a newer "
          'Porelo.';
    }
    // Asked before the person chooses an agent: a start it would refuse for its rights is said here, not after.
    if (!await _startDeclares('rights') || !await _startDeclares('projectServices')) {
      return "This machine's Porelo cannot start a discussion with the rights its planner names; it needs a "
          'newer Porelo.';
    }
    return null;
  }

  Future<bool> _declaresStartInput(String input) async {
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
      if (depth == 0) return RegExp('(?:^|,)\\s*$input\\s*:').hasMatch(inputs.toString());
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

  /// The models [provider] offers this machine, for [agent] where the provider is that agent's own sign-in.
  Future<OfferedModels> models(String provider, {String? agent}) async {
    final reply = await _call('Models', <String, dynamic>{'provider': provider, 'agent': ?agent});
    final models = reply['models'];
    return (
      models: models is List
          ? models.whereType<Map<String, dynamic>>().map(OfferedModel.from).where((each) => each.id.isNotEmpty).toList()
          : <OfferedModel>[],
      from: reply['from'] is String ? reply['from']! as String : 'none',
    );
  }

  /// What the vault holds, without any of it.
  Future<VaultState> credentials() async => VaultState.from(await _call('Credentials'));

  /// Each installed agent's sign-in state here, read from the vault once.
  Future<List<AgentSignIn>> agentSignIns() async =>
      AgentSignIn.allIn(await _call('AgentSignIns', const <String, dynamic>{}));

  /// How long [agentSignInStart] may go unanswered: the machine answers once the login container runs, and the
  /// first sign-in on a machine builds its login image before that, for which the contract names no bound.
  static Duration get signInStartWithin => serviceWait(const Duration(minutes: 15));

  /// Starts [agent]'s own login here, or answers the one that runs already: never a second. [force] signs in
  /// although the machine's own agent directory holds a sign-in; [remote] says the person reaches this machine from
  /// another one.
  ///
  /// **On a connection of its own, under [signInStartWithin] rather than the single call's deadline**, so a first
  /// sign-in is not cut off while the machine still builds its login image. Once [abandoned] completes, a start still
  /// waiting for a place gives it up and an open one's connection is closed, and it ends as [VarlinkDisconnected]; the
  /// machine's own login goes on.
  Future<SignInStarted> agentSignInStart(String agent, {bool? force, bool? remote, Future<void>? abandoned}) async {
    VarlinkConnection? connection;
    var left = false;
    unawaited(
      abandoned?.then<void>((_) {
        left = true;
        final open = connection;
        connection = null;
        unawaited(open?.close());
      }, onError: (Object _) {}),
    );
    final opened = await backend.open(use: const RelayUse.stream(), abandoned: abandoned);
    if (left) {
      await opened.close();
      throw VarlinkDisconnected('The sign-in start to ${backend.label} was no longer wanted.');
    }
    connection = opened;
    try {
      return SignInStarted.from(
        await opened.call('$interfaceName.AgentSignInStart', <String, dynamic>{
          'agent': agent,
          'force': ?force,
          'remote': ?remote,
        }, signInStartWithin),
      );
    } on VarlinkException catch (refusal) {
      if (refusal.isMethodNotFound) throw const FeatureNotSupported('AgentSignInStart');
      if (refusal.simpleName == 'SignInRefused') throw SignInRefused(refusal);
      rethrow;
    } finally {
      connection = null;
      await opened.close();
    }
  }

  /// How long [agentSignInWait] may go unanswered: the machine answers within 30 minutes, so a little past that.
  static Duration get signInWaitWithin => serviceWait(const Duration(minutes: 31));

  /// Waits until [agent]'s sign-in here ends, and answers whether the vault holds its credential then: one reply,
  /// at once where none runs.
  ///
  /// **On a connection of its own, under [signInWaitWithin] rather than the single call's deadline**, and that
  /// connection is closed when the wait is left (the subscription canceled), which does not end the sign-in.
  Stream<SignInWaited> agentSignInWait(String agent) {
    final waited = StreamController<SignInWaited>();
    VarlinkConnection? connection;
    var left = false;
    final leaving = Completer<void>();
    waited.onListen = () => unawaited(() async {
      try {
        final opened = await backend.open(use: const RelayUse.stream(), abandoned: leaving.future);
        if (left) return unawaited(opened.close());
        connection = opened;
        final reply = await opened.call('$interfaceName.AgentSignInWait', <String, dynamic>{
          'agent': agent,
        }, signInWaitWithin);
        if (!left) waited.add(SignInWaited.from(reply));
      } on VarlinkException catch (ex) {
        if (!left) waited.addError(ex.isMethodNotFound ? const FeatureNotSupported('AgentSignInWait') : ex);
      } on Object catch (ex) {
        if (!left) waited.addError(ex);
      } finally {
        await connection?.close();
        connection = null;
        if (!left) await waited.close();
      }
    }());
    waited.onCancel = () async {
      left = true;
      if (!leaving.isCompleted) leaving.complete();
      final open = connection;
      connection = null;
      await open?.close();
    };
    return waited.stream;
  }

  /// The model a start on [project] (and [repository], where named) would run on for each provider this machine
  /// knows, when the start names none.
  Future<List<ProviderModel>> providerModels(String project, {String? repository}) async => ProviderModel.allIn(
    await _call('ProviderModels', <String, dynamic>{'project': project, 'repository': ?repository}),
  );

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

  /// Allows what [repository]'s `porelo.yml` sets in `default`, and only the text [hash] names, as `CanStart` showed it.
  Future<SettingsAllowed> allowSettings(String repository, String hash) async =>
      SettingsAllowed.from(await _call('AllowSettings', <String, dynamic>{'repository': repository, 'hash': hash}));

  /// The ssh keys the account already has on the machine, never with a value.
  Future<List<SshKey>> sshKeys() async {
    final keys = (await _call('SshKeys', const <String, dynamic>{}))['keys'];
    return keys is List ? keys.whereType<Map<String, dynamic>>().map(SshKey.from).toList() : const <SshKey>[];
  }

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
    String? from,
    bool certify = false,
    bool? allRepositories,
    String? result,
    String? callerKey,
    bool? readOnly,
    Map<String, String>? given,
    TrackedWork? work,
    Map<String, Object?>? place,
    List<String>? rights,
    List<String>? readLanded,
    String? writeAs,
    bool? projectServices,
  }) async* {
    // Never dropped where the machine lacks them: without its rights a start would take the machine's default
    // set, and without its place, account or services it would be another start than the one ordered.
    for (final (input, named) in <(String, bool)>[
      ('rights', rights != null),
      // Named only by an order here: left out by a machine that takes none, the task would get a gate.
      ('noGate', noGate != null && rights != null),
      ('place', place != null),
      ('readLanded', readLanded != null),
      ('writeAs', writeAs != null),
      ('projectServices', projectServices != null),
    ]) {
      if (named && !await _startDeclares(input)) throw FeatureNotSupported('Start($input)');
    }
    // Never dropped where the machine lacks them: without them the start would be an ordinary one, a repository
    // writable, where every repository read only and a file handed back were asked.
    if (allRepositories != null && !await _startDeclares('allRepositories')) {
      throw const FeatureNotSupported('Start(allRepositories)');
    }
    if (result != null && !await _startDeclares('result')) {
      throw const FeatureNotSupported('Start(result)');
    }
    // Without it a planned stage would get its repository writable and a gate; without them it would not read the
    // issues as its planner holds them now.
    if (readOnly != null && !await _startDeclares('readOnly')) {
      throw const FeatureNotSupported('Start(readOnly)');
    }
    if (given != null && !await _startDeclares('given')) {
      throw const FeatureNotSupported('Start(given)');
    }
    // Without it a stage of a project kept in a tracker would work on nothing it can name.
    if (work != null && !await _startDeclares('work')) {
      throw const FeatureNotSupported('Start(work)');
    }
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
      // The branch a checkout here is on, which the machine cannot see; only one that takes it is told.
      if (from != null && await (_startFrom ??= _declaresStartInput('from'))) 'from': from,
      if (await (_startSteps ??= _declaresStartSteps())) 'steps': true,
      // Only one that says what to do with a request asks; an older daemon has no such input.
      if (certify && await (_startCertify ??= _declaresStartInput('certify'))) 'certify': true,
      'allRepositories': ?allRepositories,
      'result': ?result,
      'readOnly': ?readOnly,
      'given': ?given,
      if (work != null) 'work': <String, String>{'issue': work.issue, 'phase': work.phase},
      // As the planner read them: the window builds no place of its own.
      'place': ?place,
      // An empty list is sent as one: left out, the machine would give the task its default set.
      'rights': ?rights,
      'readLanded': ?readLanded,
      'writeAs': ?writeAs,
      'projectServices': ?projectServices,
      // Only a help to find the task again: a machine that keeps none starts the same task without it.
      if (callerKey != null && await _startDeclares('callerKey')) 'callerKey': callerKey,
    };
    yield* _callMore('Start', parameters).map(StartProgress.from);
  }

  /// Answers a start's [StartProgress.certify]: the certificate this computer's agent made, or why not.
  Future<void> certifyStart(String start, {String? certificate, String? refused}) async {
    await _call('Certify', {'start': start, 'certificate': ?certificate, 'refused': ?refused});
  }

  /// Stops a task, keeping it: its container is its workspace. Removing is [remove].
  Future<Stopped> stop(String task) async => Stopped.from(await _call('Stop', {'task': task}));

  /// Removes a task, or refuses rather than destroys.
  ///
  /// A task holding commits that never reached the gate comes back as [Outcome.holdsWork],
  /// untouched. That refusal needs a real place in the interface - it is the product working.
  Future<Removed> remove(String task, {bool? rescue, bool? force}) async =>
      Removed.from(await _call('Remove', {'task': task, 'rescue': ?rescue, 'force': ?force}));

  /// The reports [task] made after the one numbered [after], all where it is null, oldest first: as many as one
  /// answer holds, with [TaskReports.more] where some were left out.
  Future<TaskReports> reports(String task, {int? after}) async {
    final page = TaskReports.from(await _call('Reports', {'task': task, 'after': ?after}));
    if (after != null && page.reports.any((report) => report.seq <= after)) {
      throw FormatException('Reports answered a report at or before $after');
    }
    return page;
  }

  /// Every project on the machine.
  ///
  /// Nothing refreshes this: `WatchProjects` is not used yet, so it is asked again after anything
  /// that would change it — a task started or removed, a push approved.
  Future<List<Project>> projects() async {
    final reply = await _call('Projects');
    final projects = reply['projects'];
    return projects is List ? projects.whereType<Map<String, dynamic>>().map(Project.from).toList() : const <Project>[];
  }

  /// Takes a project the machine carries for this person, so that it stands here with its file.
  ///
  /// For a person's act and never for a list: it fetches once and, on a host, asks one forge token. An older daemon
  /// raises [FeatureNotSupported], for this call alone.
  Future<TakenProject> takeProject(String project) async =>
      TakenProject.from(await _call('TakeProject', {'project': project}));

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
  Future<(List<EgressHost>, List<String>, List<RemovedSetting>)> egress(
    String project, {
    String? agent,
    String? repository,
  }) async {
    final reply = await _call('Egress', {'project': project, 'agent': ?agent, 'repository': ?repository});
    final hosts = reply['hosts'];
    final refused = reply['refused'];
    return (
      hosts is List ? hosts.whereType<Map<String, dynamic>>().map(EgressHost.from).toList() : <EgressHost>[],
      refused is List ? refused.whereType<String>().toList() : <String>[],
      RemovedSetting.list(reply['removed']),
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
    bool? allRepositories,
  }) async => Readiness.from(
    await _call('CanStart', {
      'allRepositories': ?allRepositories,
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

  /// The result file [task] handed back at its end, with its content: kept until the task's next start or its removal.
  Future<TaskResult> result(String task) async => TaskResult.from(await _call('Result', {'task': task}));

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

  /// The sign-ins this machine's installed agents hold, by name only. Not cheap: each agent is asked per provider.
  Future<List<ImportableCredential>> importableCredentials() async {
    final rows = (await _call('ImportableCredentials', const <String, dynamic>{}))['rows'];
    return rows is List
        ? rows.whereType<Map<String, dynamic>>().map(ImportableCredential.from).toList()
        : const <ImportableCredential>[];
  }

  /// A one-use key on this host to seal a credential to.
  Future<CredentialReceiver> credentialReceiver() async =>
      CredentialReceiver.from(await _call('CredentialReceiver', const <String, dynamic>{}));

  /// Seals one credential of this machine to a host's [key]: a vault entry by [name], or an agent's own sign-in.
  Future<SealedCredential> sealCredential({
    required String key,
    String? name,
    String? agent,
    String? provider,
    String? configDirectory,
  }) async => SealedCredential.from(
    await _call('SealCredential', {
      'key': key,
      'name': ?name,
      'agent': ?agent,
      'provider': ?provider,
      'configDirectory': ?configDirectory,
    }),
  );

  /// Opens what was sealed to this host's key and stores it under [name].
  Future<ReceivedCredential> receiveCredential({
    required String sealed,
    required String name,
    required String kind,
    required bool replace,
  }) async => ReceivedCredential.from(
    await _call('ReceiveCredential', {'sealed': sealed, 'name': name, 'kind': kind, 'replace': replace}),
  );

  /// Keeps [identity] in this computer's vault for [host]. Without [replace], only one that adds repositories to what
  /// is kept is taken; anything else is [HostIdentityExists], and nothing changes.
  Future<void> hostIdentityKeep(String host, HostIdentity identity, {bool replace = false}) =>
      _aboutIdentities(() => _call('HostIdentityKeep', {'host': host, 'identity': identity.wire, 'replace': replace}));

  /// The whole identity the vault keeps for [host], private halves included: only for the moment it is handed to the
  /// host's setup.
  Future<HostIdentity> hostIdentityRead(String host) =>
      _aboutIdentities(() async => HostIdentity.read((await _call('HostIdentityRead', {'host': host}))['identity']));

  /// What the vault keeps for [host], without any private half.
  Future<HostIdentityPublic> hostIdentityPublic(String host) => _aboutIdentities(
    () async => HostIdentityPublic.read((await _call('HostIdentityPublic', {'host': host}))['identity']),
  );

  /// The hosts whose identity the vault keeps, sorted.
  Future<List<String>> hostIdentities() => _aboutIdentities(() async {
    final hosts = (await _call('HostIdentities', const <String, dynamic>{}))['hosts'];
    if (hosts is! List) throw const FormatException('HostIdentities answered no list');
    return hosts.whereType<String>().toList();
  });

  /// The forges this machine knows, and the forge adapters installed on it.
  Future<MachineForges> forges() async =>
      MachineForges.from(await _supported('Forges', () => _call('Forges', const <String, dynamic>{})));

  /// Makes [host] known to this machine as a forge reached by [adapter], an installed forge adapter by the name
  /// [forges] lists it; [comments] is `TRUSTED` only on the person's own choice, and absent keeps it extended.
  Future<void> forgeSet(String host, String adapter, {String? comments}) =>
      _supported('ForgeSet', () => _call('ForgeSet', {'host': host, 'adapter': adapter, 'comments': ?comments}));

  /// [call], a machine older than [method] answering [FeatureNotSupported] for it alone.
  static Future<T> _supported<T>(String method, Future<T> Function() call) async {
    try {
      return await call();
    } on VarlinkException catch (refusal) {
      if (refusal.isMethodNotFound) throw FeatureNotSupported(method);
      rethrow;
    }
  }

  /// Says each way a call about an identity fails as its own [HostIdentityFailure]: only the vault's own word that it
  /// keeps none is ever read as none.
  static Future<T> _aboutIdentities<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on FeatureNotSupported {
      throw const HostIdentityUnsupported();
    } on VarlinkDisconnected catch (ex) {
      throw HostIdentityUnreached(ex.message);
    } on SocketException catch (ex) {
      throw HostIdentityUnreached(ex.message);
    } on FormatException {
      // An answer that is no identity is refused as one, never taken for one or for none.
      throw const HostIdentityRefused(HostIdentityRefused.malformed, '');
    } on VarlinkException catch (ex) {
      final host = ex.parameters['host'];
      throw switch (ex.simpleName) {
        'HostIdentityUnknown' => HostIdentityUnknown(host is String ? host : ''),
        'HostIdentityExists' => HostIdentityExists(host is String ? host : ''),
        'VaultLocked' => const HostIdentityVaultShut(),
        final name => HostIdentityRefused(name, switch (ex.parameters['parameter']) {
          final String field => field,
          _ => '',
        }),
      };
    }
  }

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

  /// The person's account settings on this machine, as its porelod read them from their config.yml.
  Future<AccountSettings> accountSettings() async =>
      AccountSettings.from(await _call('AccountSettings', const <String, dynamic>{}));

  /// The limits line the machine's Porelo gives: its four time factors, as Limits() answers them.
  Future<String> limitsLine() async {
    final answered = await _call('Limits', const <String, dynamic>{});
    final line = answered['line'];
    if (line is! String) throw const FormatException('Limits answered no line');
    return line;
  }

  /// Brings [task]'s repository at the gate up to its source and tells its agent what moved.
  Future<TaskRefreshed> refreshTask(String task) async =>
      TaskRefreshed.from(await _call('RefreshTask', {'task': task}));

  /// Clears this machine of a project, or of every project with none named: its tasks, workspaces,
  /// gate, mirrors and conversation, leaving what only a person's credentials remove named.
  Future<Cleared> clear({String? project, bool? dryRun, bool? force}) async =>
      Cleared.from(await _call('Clear', {'project': ?project, 'dryRun': ?dryRun, 'force': ?force}));

  /// Removes a project registered on this machine alone, and everything Porelo built for it here.
  ///
  /// It **refuses rather than decides**: unreviewed pushes exist only in the mirror and a running
  /// task is work cut off mid-flight. [force] is how somebody says they meant it. The project's own
  /// repository is not on this machine and is never touched. A project of the organization and
  /// `default` are refused. An older daemon raises [FeatureNotSupported], for this call alone.
  Future<Deletion> removeProject(String name, {bool? dryRun, bool? force}) async =>
      Deletion.from(await _call('RemoveProject', {'name': name, 'dryRun': ?dryRun, 'force': ?force}));

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
      _chunkOf(await _call('Tail', {'task': task, 'log': log})).lines;

  /// Follows a task's log as it is written.
  ///
  /// With [last], it starts from the log's last that many lines rather than its first; with
  /// [formatted], every line comes as the task's agent shows it, hidden ones left out. Both are sent
  /// only when given, so a Porelo older than them is asked what it knows.
  Stream<LogChunk> tailLog(String task, String log, {int? last, bool formatted = false}) =>
      _callMore('Tail', {'task': task, 'log': log, 'last': ?last, if (formatted) 'formatted': true}).map(_chunkOf);

  /// The [lines] of a task's log that lie just before the byte position [before], which `Tail` or an earlier
  /// call of this gave as its offset, in the log [of] names; [lines] is 1 to 1000.
  ///
  /// A page, not a stream. A log replaced by a new run is the `NoSuchLog` refusal, which the caller answers by
  /// reading from `Tail` again; any other refusal is raised as it came. A reply missing a part is a
  /// [FormatException], never taken for the log's start.
  Future<LogPage> logBefore(
    String task,
    String log, {
    required String of,
    required int before,
    required int lines,
    bool formatted = false,
  }) async {
    RangeError.checkValueInInterval(lines, 1, 1000, 'lines');
    final reply = await _call('LogBefore', {
      'task': task,
      'log': log,
      'of': of,
      'before': before,
      'lines': lines,
      if (formatted) 'formatted': true,
    });
    final read = reply['lines'];
    final offset = reply['offset'];
    final atStart = reply['atStart'];
    if (read is! List || offset is! int || atStart is! bool) {
      throw const FormatException('LogBefore answered without its lines, offset and atStart');
    }
    return LogPage(lines: read.whereType<String>().toList(), offset: offset, atStart: atStart);
  }

  /// What [task]'s terminal session shows now, its last [last] lines, without attaching: nobody in
  /// the session sees anything happen. With [escapes], the lines keep the terminal's colours.
  Future<Screen> screen(String task, {required int last, bool escapes = false}) async =>
      Screen.from(await _call('Screen', {'task': task, 'last': last, if (escapes) 'escapes': true}));

  /// The lines of [task]'s terminal session that lie before the byte position [before], at most [lines] of them (1 to
  /// 1000), from the recording [of] names. [before] is the `end` of [screen] or the offset of the page before.
  ///
  /// Every answer the daemon refuses with, a method it does not serve included, stays its own [VarlinkException].
  Future<ScreenPage> screenBefore(
    String task, {
    required String of,
    required int before,
    required int lines,
    bool escapes = false,
  }) async => ScreenPage.from(
    await _call('ScreenBefore', {
      'task': task,
      'of': of,
      'before': before,
      'lines': lines,
      if (escapes) 'escapes': true,
    }),
  );

  /// What [task] used, as far as its agent's requests reported it, without network access.
  Future<Usage> usage(String task) async {
    final reply = await _call('Usage', {'task': task});
    return Usage.from(reply['usage'] is Map ? (reply['usage'] as Map).cast<String, dynamic>() : const {});
  }

  /// What [task]'s image was built with and where each thing came from, as the image recorded it.
  Future<ImageSettings> imageSettings(String task) async =>
      ImageSettings.from(await _call('ImageSettings', {'task': task}));

  /// What a first start in [checkout], a folder of the machine's own computer, is to do. Changes nothing.
  Future<FirstStart> firstStart(String checkout) async =>
      FirstStart.from(await _call('FirstStart', {'checkout': checkout}));

  /// A person's yes to the text [hash] names: answers the project a start then names.
  Future<String> confirmFirstStart(String checkout, String hash) async {
    final reply = await _call('ConfirmFirstStart', {'checkout': checkout, 'hash': hash});
    return reply['project'] as String? ?? '';
  }

  // --------------------------------------------------------------------- the gate

  /// What is waiting at a project's gate.
  ///
  /// [repository] is one of `Project.repositories`; without one a Porelo answers the project's own
  /// and an older one knows no other.
  Future<GateState> gate(String project, {String? upstream, String? repository}) async =>
      GateState.from(await _call('Pending', {'project': project, 'upstream': ?upstream, 'repository': ?repository}));

  /// The pull requests open on the forge of the host that carries [project], read with the person's forge token.
  /// Refused with [MissingHostForgeToken] or [HostPullRequestsRefused]. A list in pages is read whole; one the machine
  /// let go of meanwhile is refused with `PullRequestsReadingGone`, and the caller asks again.
  Future<PullRequestsSeen> pullRequests(String project) async {
    try {
      return await _wholePullRequests(project, await _call('PullRequests', {'project': project}));
    } on VarlinkException catch (refusal) {
      throw HostPullRequestsRefused.typed(refusal);
    }
  }

  /// The same, then each change: the whole open list again, with those seen to end. It ends only on an error, after
  /// which what it said is stale and is asked for again.
  ///
  /// A snapshot too large for one message is read whole with `PullRequestsPage` before it is given. One is read at a
  /// time, to its end, so a list that keeps changing still reaches the window; of those that come meanwhile only the
  /// newest waits, and it is read next. A reading the machine let go of goes over to that newest one; with none
  /// waiting, it ends the stream, as a page the machine refused and pages that do not fit together do: an unchanged
  /// list is not sent again, so waiting for the next snapshot could leave an old list unmarked. The ends a skipped
  /// snapshot confirmed go with the next one given, so a pull request that ended is not kept as open.
  Stream<PullRequestsSeen> watchPullRequests(String project) {
    final whole = StreamController<PullRequestsSeen>();
    StreamSubscription<Map<String, dynamic>>? raw;
    Map<String, dynamic>? waiting;
    var reading = false;
    var rawDone = false;
    var cancelled = false;
    bool wanted() => !cancelled && !whole.isClosed;
    // The ends confirmed by snapshots skipped for the one waiting, as far as their first rows hold them: they go with
    // that one, never with the one read meanwhile, which came before them.
    var carried = <String, HostPullRequest>{};
    void carry(Map<String, dynamic> skipped, [Map<String, HostPullRequest> also = const {}]) {
      carried.addAll(also);
      try {
        for (final each in PullRequestsSeen.from(skipped).ended) {
          carried[each.key] = each;
        }
      } on Object {
        // A skipped snapshot that cannot be read carries nothing.
      }
    }

    void end(Object error, [StackTrace? stack]) {
      if (whole.isClosed) return;
      whole.addError(HostPullRequestsRefused.typed(error), stack);
      unawaited(raw?.cancel());
      unawaited(whole.close());
    }

    Future<void> readOn() async {
      reading = true;
      while (waiting != null && wanted()) {
        final reply = waiting!;
        waiting = null;
        final withIt = carried;
        carried = <String, HostPullRequest>{};
        final PullRequestsSeen seen;
        try {
          seen = await _wholePullRequests(project, reply, wanted: wanted);
        } on _Overtaken {
          break;
        } on VarlinkException catch (gone, stack) {
          // A reading the machine let go of, or a page it no longer takes, while a newer snapshot waits: that one is
          // read instead.
          if (waiting != null && const {'PullRequestsReadingGone', 'InvalidParameter'}.contains(gone.simpleName)) {
            carry(reply, withIt);
            continue;
          }
          end(gone, stack);
          break;
        } on Object catch (error, stack) {
          end(error, stack);
          break;
        }
        if (!wanted()) break;
        final open = {for (final each in seen.open) each.key};
        final ends = {for (final each in seen.ended) each.key};
        final also = [
          for (final MapEntry(:key, :value) in withIt.entries)
            if (!open.contains(key) && !ends.contains(key)) value,
        ];
        whole.add(
          also.isEmpty
              ? seen
              : PullRequestsSeen(open: seen.open, ended: [...seen.ended, ...also], refused: seen.refused),
        );
      }
      reading = false;
      if (rawDone && !whole.isClosed) unawaited(whole.close());
    }

    whole
      ..onListen = () {
        raw = _callMore('WatchPullRequests', {'project': project}).listen(
          (reply) {
            if (waiting case final skipped?) carry(skipped);
            waiting = reply;
            if (!reading) unawaited(readOn());
          },
          onError: end,
          onDone: () {
            rawDone = true;
            if (!reading && !whole.isClosed) unawaited(whole.close());
          },
          cancelOnError: true,
        );
      }
      ..onCancel = () async {
        cancelled = true;
        waiting = null;
        await raw?.cancel();
      };
    return whole.stream;
  }

  /// At most this many pages are asked for one reading: past it, its pages are taken for ones that never end.
  static const pullRequestPagesAtMost = 10000;

  /// At most this many rows are taken from one reading: a count above it is refused before any page is asked.
  static const pullRequestRowsAtMost = 100000;

  /// [reply] as the whole reading: as it came where it is whole, else with every page `PullRequestsPage` gives after
  /// it, checked to fit together. Throws [PullRequestsPagingBroken] where they do not, and [_Overtaken] once [wanted]
  /// says the reading is no longer wanted.
  Future<PullRequestsSeen> _wholePullRequests(
    String project,
    Map<String, dynamic> reply, {
    bool Function()? wanted,
  }) async {
    final paged = reply['paged'];
    if (paged == null) return PullRequestsSeen.from(reply);
    Never broken(String what) => throw PullRequestsPagingBroken(project, what);
    final first = PullRequestsSeen.from(reply);
    if (paged is! Map) broken('it named its pages in a form this window cannot read');
    final reading = paged['reading'];
    final counted = paged['pullRequests'];
    final countedEnded = paged['ended'];
    var next = paged['next'];
    if (reading is! String || !RegExp(r'^[0-9a-f]{32}$').hasMatch(reading)) broken('it named no reading');
    if (counted is! int || countedEnded is! int || next is! int || counted < 0 || countedEnded < 0) {
      broken('it named no counts or no next page');
    }
    final open = [...first.open];
    final ended = [...first.ended];
    final all = counted + countedEnded;
    if (all > pullRequestRowsAtMost) broken('it counted $all rows, more than the $pullRequestRowsAtMost read at most');
    // The rows so far must be the first of the reading, open ones before ended ones, and [at] must follow them.
    void fits(int at) {
      if (open.length > counted || ended.length > countedEnded) broken('it gave more rows than it counted');
      if (ended.isNotEmpty && open.length < counted) broken('it gave ended pull requests before every open one');
      final held = open.length + ended.length;
      if (at != held) broken('it named row $at as next after $held rows');
      if (held >= all) broken('it named a next page after all $all rows');
    }

    fits(next);
    for (var pages = 0; ; pages++) {
      if (pages >= pullRequestPagesAtMost) broken('it gave more than $pullRequestPagesAtMost pages');
      if (wanted != null && !wanted()) throw const _Overtaken();
      final Map<String, dynamic> page;
      try {
        page = await _call('PullRequestsPage', {'project': project, 'reading': reading, 'from': next});
      } on FeatureNotSupported {
        // It named pages it cannot give: not a machine older than pull requests, whose list would then go unsaid.
        broken('it named pages but gives none');
      }
      if (wanted != null && !wanted()) throw const _Overtaken();
      final rows = PullRequestsSeen.from(page);
      if (rows.open.isEmpty && rows.ended.isEmpty) broken('a page held no row');
      open.addAll(rows.open);
      ended.addAll(rows.ended);
      final after = page['next'];
      if (after == null) {
        if (open.length != counted || ended.length != countedEnded) {
          broken('its pages ended with ${open.length} open and ${ended.length} ended of $counted and $countedEnded');
        }
        if ({for (final each in open) each.key}.length != open.length ||
            {for (final each in ended) each.key}.length != ended.length) {
          broken('its pages gave a pull request twice');
        }
        return PullRequestsSeen(open: open, ended: ended, refused: first.refused);
      }
      if (after is! int) broken('a page named its next in a form this window cannot read');
      fits(after);
      next = after;
    }
  }

  /// Brings the host's approved `main` of [project]'s [repositories] (all its push configuration names, where null)
  /// to the central forge, stage by stage; it ends on the reply naming what was pushed, or on a [CentralPushRefusal].
  /// Streamed, as a push takes as long as it takes, and a single call's deadline would cut it short.
  Stream<CentralPushProgress> pushToCentral(String project, {List<String>? repositories}) =>
      _callMore('PushToCentral', {'project': project, 'repositories': ?repositories})
          .map(CentralPushProgress.from)
          .handleError(
            (Object refusal) => throw CentralPushRefusal.typed(refusal),
            test: (error) => error is VarlinkException,
          );

  /// What a pending push contains: a diff and a log, and, from a Porelo that ranks the review, its
  /// files in the order to show them and what the task that pushed was asked.
  ///
  /// `asked` is null where the machine does not say, an empty string where the task was started
  /// without an instruction; `files` is empty from a Porelo older than the ranked review; `commits`,
  /// newest first with who made each, is null from a Porelo older than that field. With
  /// [ignoreLineEndings] `true` the diff leaves out what changed at line ends; only a machine whose
  /// `Review` declares it may be sent it.
  ///
  /// A `paged` that does not match what the answer holds of its files, commits or diff - a next where a
  /// part is already whole, none where it is not, or more held than its size - is refused as a
  /// [FormatException]. The log is not checked: it is never shown, and its pages are not read.
  Future<PushReview> review(
    String project,
    String name, {
    String? upstream,
    String? against,
    String? repository,
    bool? ignoreLineEndings,
  }) async {
    final reply = await _call('Review', {
      'project': project,
      'name': name,
      'upstream': ?upstream,
      'against': ?against,
      'repository': ?repository,
      // Sent only when asked: a machine older than the switch refuses a parameter it does not know.
      if (ignoreLineEndings == true) 'ignoreLineEndings': true,
    });
    final diff = reply['diff'];
    final log = reply['log'];
    final files = reply['files'];
    final asked = reply['asked'];
    final commit = reply['commit'];
    final review = PushReview(
      diff: diff is String ? diff : '',
      log: log is String ? log : '',
      files: files is List
          ? files.whereType<Map<String, dynamic>>().map(ReviewFile.from).toList()
          : const <ReviewFile>[],
      asked: asked is String ? asked : null,
      commits: ReviewCommit.allIn(reply['commits']),
      commit: commit is String && commit.isNotEmpty ? commit : null,
      cut: reply['cut'] == null ? null : ReviewCut.from(reply['cut']),
      paged: reply['paged'] == null ? null : ReviewPaged.from(reply['paged']),
    );
    final paged = review.paged;
    if (paged != null) {
      void held(String part, int count, int size, int? next) {
        if (count > size) throw FormatException('Review holds more $part than paged says there are');
        if ((next == null) != (count == size)) {
          throw FormatException('Review.paged names a next page of $part that does not match what it holds');
        }
      }

      held('files', review.files.length, paged.files, paged.filesNext);
      held('commits', review.commits?.length ?? 0, paged.commits, paged.commitsNext);
      // A cut diff says itself that it is not whole, and its size is not the one the pages count.
      if (review.cut == null) held('diff', utf8.encode(review.diff).length, paged.diffBytes, paged.diffNext);
    }
    return review;
  }

  /// How many findings and review threads are open on the waiting push [name] at [commit], and how far each check
  /// run got.
  ///
  /// Refused, as [review] is, with `NoSuchPush` or `MovedSinceReview`; a machine without it answers
  /// [FeatureNotSupported], and an answer without its counts is a [FormatException], never zeros.
  Future<ReviewSummary> reviewSummary(
    String project,
    String name, {
    String? repository,
    required String commit,
  }) async => ReviewSummary.from(
    await _call('ReviewSummary', {'project': project, 'repository': ?repository, 'name': name, 'commit': commit}),
  );

  /// One more page of a part of [name]'s review, for [commit], read [against] as `Review.paged.base` names it,
  /// from [from]: a position the machine gave. [part] is `files`, `commits`, `log` or `diff`.
  ///
  /// An answer without the part asked for, or with a next that is no whole number, is refused as a
  /// [FormatException]. A machine without `ReviewPage` answers [FeatureNotSupported].
  Future<ReviewPage> reviewPage(
    String project,
    String name, {
    String? upstream,
    String? repository,
    required String commit,
    required String against,
    required bool ignoreLineEndings,
    required String part,
    required int from,
  }) async {
    final reply = await _call('ReviewPage', {
      'project': project,
      'upstream': ?upstream,
      'repository': ?repository,
      'name': name,
      'commit': commit,
      'against': against,
      'ignoreLineEndings': ignoreLineEndings,
      'part': part,
      'from': from,
    });
    final next = reply['next'];
    if (next != null && next is! int) throw const FormatException('ReviewPage.next is not a position');
    switch (part) {
      case 'files':
        final files = reply['files'];
        if (files is! List || files.any((each) => each is! Map<String, dynamic>)) {
          throw const FormatException('ReviewPage holds no files');
        }
        return (
          files: files.cast<Map<String, dynamic>>().map(ReviewFile.from).toList(),
          commits: null,
          text: null,
          next: next as int?,
        );
      case 'commits':
        final commits = ReviewCommit.allIn(reply['commits']);
        if (commits == null) throw const FormatException('ReviewPage holds no commits');
        return (files: null, commits: commits, text: null, next: next as int?);
      default:
        final text = reply['text'];
        if (text is! String) throw FormatException('ReviewPage holds no text of $part');
        return (files: null, commits: null, text: text, next: next as int?);
    }
  }

  /// Forwards a pending push upstream.
  ///
  /// The only call that sends anything anywhere, and it makes the caller name the branch.
  Future<ForwardedPush> approve(
    String project,
    String name,
    String branch, {
    String? upstream,
    String? repository,
    String? commit,
  }) async => ForwardedPush.from(
    await _call('Approve', {
      'project': project,
      'name': name,
      'branch': branch,
      'upstream': ?upstream,
      'repository': ?repository,
      'commit': ?commit,
    }),
  );

  /// Tries [refspec] with one ssh key alone, as a dry run: nothing is pushed and nothing is kept.
  /// [source] is `AGENT` (with [id] a fingerprint) or `FILE` (with [id] a path on the machine).
  Future<TriedPush> credentialTryPush(
    String project, {
    String? repository,
    required String refspec,
    required String source,
    required String id,
  }) async => TriedPush.from(
    await _call('CredentialTryPush', {
      'project': project,
      'repository': ?repository,
      'refspec': refspec,
      'source': source,
      'id': id,
    }),
  );

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

  /// How the gate's record of the push at [place] stands: its decision, and the task that rejected it, if one did.
  ///
  /// Asked once a push has left the list of waiting ones. The task is left to the machine, which at a gate
  /// push takes the one that pushed.
  Future<PushEnd> reviewOpen(String project, RunPlace place) async =>
      PushEnd.from(await _call('ReviewOpen', {'project': project, 'place': place.toWire()}));

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

  /// Sets [project]'s room up on this machine, taking a project it carries for this person first; null when the
  /// project has no conversation.
  Future<ProjectMessages?> setUpMessages(String project) async =>
      ProjectMessages.of((await _call('SetUpMessages', <String, dynamic>{'project': project}))['messages']);

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

  /// The repositories worked on in the Default project, in [defaultProject].
  Future<List<DefaultRepository>> defaultRepositories() async {
    final reply = await _call('DefaultRepositories');
    final listed = reply['repositories'];
    return listed is List
        ? listed.whereType<Map<String, dynamic>>().map(DefaultRepository.from).toList()
        : const <DefaultRepository>[];
  }

  /// The repositories of [defaultProject] that a project of the organization names, each with that project and its
  /// key there; empty where the organization names none. A Porelo without it throws [FeatureNotSupported].
  Future<List<NamedDefaultRepository>> namedDefaultRepositories() async {
    final reply = await _call('NamedDefaultRepositories');
    final listed = reply['repositories'];
    return listed is List
        ? listed.whereType<Map<String, dynamic>>().map(NamedDefaultRepository.from).toList()
        : const <NamedDefaultRepository>[];
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

  /// Takes [name], which a project of the organization names now, out of [defaultProject], through the removal
  /// [removeFromDefault] makes; refused with `DefaultRepositoryInUse` while a task of it works on the repository, and
  /// with `NoSuchDefaultRepository` for a name it does not have. A Porelo without LeaveDefault is asked
  /// RemoveFromDefault instead.
  Future<({bool removed, List<MachineDeployKey> keys})> leaveDefault(String name) async {
    final Map<String, dynamic> reply;
    try {
      reply = await _call('LeaveDefault', <String, dynamic>{'name': name});
    } on FeatureNotSupported {
      return removeFromDefault(name);
    }
    final keys = reply['keys'];
    return (
      removed: reply['removed'] is Map,
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
      return await connection.call(
        qualify ? '$interfaceName.$method' : method,
        parameters,
        serviceWait(answerWithin, machine: machine),
      );
    } on VarlinkException catch (ex) {
      if (ex.isMethodNotFound) throw FeatureNotSupported(method);
      rethrow;
    } finally {
      await connection.close();
    }
  }

  /// The watches the window holds while it watches a machine, each on a connection of its own for as long as it runs.
  static const watches = {'Watch', 'Prompts', 'Talk', 'Authorizations'};

  /// The streams without end that follow one thing among many, as many as the window follows.
  static const follows = {'WatchPullRequests', 'Tail'};

  /// A stream on a connection of its own; canceled while it still waits for a place, it starts nothing.
  Stream<Map<String, dynamic>> _callMore(String method, [Map<String, dynamic> parameters = const {}]) {
    final use = watches.contains(method)
        ? RelayUse.watch(method)
        : follows.contains(method)
        ? const RelayUse.follow()
        : const RelayUse.stream();
    final left = Completer<void>();
    final replies = StreamController<Map<String, dynamic>>();
    VarlinkConnection? connection;
    StreamSubscription<Map<String, dynamic>>? reading;
    replies.onListen = () => unawaited(() async {
      final VarlinkConnection opened;
      try {
        opened = await backend.open(use: use, abandoned: left.future);
      } on Object catch (error, stack) {
        if (!left.isCompleted) {
          replies.addError(error, stack);
          await replies.close();
        }
        return;
      }
      if (left.isCompleted) return unawaited(opened.close());
      connection = opened;
      reading = opened
          .callMore('$interfaceName.$method', parameters)
          .handleError(
            (Object error) => throw FeatureNotSupported(method),
            test: (dynamic error) => error is VarlinkException && error.isMethodNotFound,
          )
          .listen(
            replies.add,
            onError: replies.addError,
            onDone: () async {
              await opened.close();
              await replies.close();
            },
          );
      if (replies.isPaused) reading!.pause();
    }());
    replies.onPause = () => reading?.pause();
    replies.onResume = () => reading?.resume();
    replies.onCancel = () async {
      if (!left.isCompleted) left.complete();
      await reading?.cancel();
      await connection?.close();
    };
    return replies.stream;
  }

  static List<Task> _tasksOf(Map<String, dynamic> reply) {
    final tasks = reply['tasks'];
    return tasks is List ? tasks.whereType<Map<String, dynamic>>().map(Task.from).toList() : const [];
  }

  // Without the log name and position, earlier lines cannot be asked for safely.
  static LogChunk _chunkOf(Map<String, dynamic> reply) {
    final offset = reply['offset'];
    final of = reply['of'];
    if (offset is! int || of is! String) {
      throw const FormatException('Tail answered without the offset of its first line or its log name');
    }
    return LogChunk(_linesOf(reply), offset: offset, of: of);
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

  /// What the host asks this computer to certify before it goes on; null on all other replies.
  final StartCertify? certify;

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

  /// The branch the work started from, once settled; null where the machine did not say.
  final String? baseBranch;

  /// Where [baseBranch] came from: `CHECKOUT`, `FROM`, `PROJECT` or `DEFAULT`, or another word a later Porelo adds.
  final String? baseSource;

  /// Constructor taking every field.
  const StartProgress({
    this.line,
    this.step,
    this.certify,
    this.steps = const <StartStep>[],
    this.container,
    this.exitCode,
    this.action,
    this.helpersStarted,
    this.helpersRecorded,
    this.problems = const <String>[],
    this.imageDrift = '',
    this.output = const <String>[],
    this.baseBranch,
    this.baseSource,
  });

  /// The same reply, carrying [lines] as what the launch printed.
  StartProgress withOutput(List<String> lines) => StartProgress(
    line: line,
    step: step,
    certify: certify,
    steps: steps,
    container: container,
    exitCode: exitCode,
    action: action,
    helpersStarted: helpersStarted,
    helpersRecorded: helpersRecorded,
    problems: problems,
    imageDrift: imageDrift,
    output: List<String>.unmodifiable(lines),
    baseBranch: baseBranch,
    baseSource: baseSource,
  );

  /// Reads one from a reply.
  factory StartProgress.from(Map<String, dynamic> map) {
    final line = map['line'];
    final step = map['step'];
    final certify = map['certify'];
    final steps = map['steps'];
    final container = map['container'];
    final exitCode = map['exitCode'];
    final action = map['action'];
    final started = map['helpersStarted'];
    final recorded = map['helpersRecorded'];
    final problems = map['problems'];
    final drift = map['imageDrift'];
    final output = map['output'];
    final baseBranch = map['baseBranch'];
    final baseSource = map['baseSource'];
    return StartProgress(
      line: line is String ? line : null,
      step: step is Map<String, dynamic> ? StartStep.from(step) : null,
      certify: certify is Map<String, dynamic> ? StartCertify.from(certify) : null,
      steps: steps is List ? steps.whereType<Map<String, dynamic>>().map(StartStep.from).toList() : const <StartStep>[],
      container: container is String ? container : null,
      exitCode: exitCode is num ? exitCode.toInt() : null,
      action: action is String ? StartAction(action) : null,
      helpersStarted: started is num ? started.toInt() : null,
      helpersRecorded: recorded is num ? recorded.toInt() : null,
      problems: problems is List ? problems.whereType<String>().toList() : const <String>[],
      imageDrift: drift is String ? drift : '',
      output: output is List ? output.whereType<String>().toList() : const <String>[],
      baseBranch: baseBranch is String && baseBranch.isNotEmpty ? baseBranch : null,
      baseSource: baseSource is String && baseSource.isNotEmpty ? baseSource : null,
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
