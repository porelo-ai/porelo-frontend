import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'agent_sign_in.dart';
import 'fleet_backend.dart';
import 'quiet_after_dispose.dart';
import 'task_names.dart';
import 'templates.dart';

/// Starting work: which project, which agent, which way of being involved, and what to ask for.
///
/// The mode is the part worth being careful about. It is not decoration on a start button — it
/// says whether a person is going to be there. `Start` will default it (`UNATTENDED` when a
/// prompt is given, `SHELL` otherwise), and the default is deliberately not relied on here,
/// because work is started *with* a mode, and a screen that quietly picked one
/// would be answering that for somebody.
class StartWork extends ChangeNotifier with QuietAfterDispose {
  /// Constructor: the sign-in it owns asks again whether work can start once the machine says signed in.
  StartWork() {
    signIn
      ..onSignedIn = askAgain
      ..addListener(notifyListeners);
  }

  /// The sign-in of the agent to run, on the machine the form was opened on: owned here, not by the dialog, so a
  /// rebuild or a step back never drops what it waits on.
  final SigningIn signIn = SigningIn();

  @override
  void dispose() {
    signIn
      ..removeListener(notifyListeners)
      ..dispose();
    super.dispose();
  }

  /// Which project the work starts in, or null when nothing is being started.
  Project? project;

  /// The agents installed on this machine.
  List<Agent> agents = const <Agent>[];

  /// Agents that could not be read, and why. Shown rather than dropped: an agent missing from a
  /// list is indistinguishable from one that was never installed.
  Map<String, String> failures = const <String, String>{};

  /// Which agent was chosen, by the name `Agents` reports.
  String? agent;

  /// How somebody is meant to be involved. **Null until chosen.**
  Mode? mode;

  /// Which repository work starts in: the row it opened from, the only one, or a choice in the form.
  String? repository;

  /// The repository whose row opened this form, or null for a project-wide start.
  String? openedForRepository;

  /// The project's repositories an organization's machine has taken, where it said so; null offers every one, as on
  /// a machine that is no organization's.
  Set<String>? takenHere;

  /// Why the project's other repositories are not offered, one line per reason; null where all are.
  String? notOfferedWords;

  /// Offers only [taken], the repositories the machine has, saying [words] of the others: a task started in one it
  /// does not have would have nothing to work in.
  void offerOnly(Set<String> taken, String? words) {
    takenHere = taken;
    notOfferedWords = words;
    if (openedForRepository != null && !taken.contains(openedForRepository)) openedForRepository = null;
    if (repository != null && !taken.contains(repository)) {
      // Unchosen as a choice is: its name and its answer went with it.
      repository = null;
      readiness = null;
      _suggestAName();
    }
    notifyListeners();
    // One left to work in has nothing to choose, as on opening.
    final offered = offeredRepositories;
    if (repository == null && offered.length == 1) chooseRepository(offered.single);
  }

  /// Forgets what a machine said it has, for a start opened afresh.
  void _offerEvery() {
    takenHere = null;
    notOfferedWords = null;
  }

  /// The repositories to choose among: the work repositories, of them only those the machine has where it said.
  List<String> get offeredRepositories => [
    for (final name in project?.workRepositories ?? const <String>[])
      if (takenHere == null || takenHere!.contains(name)) name,
  ];

  /// The checkout on this computer this start was asked from, or null where none was.
  CheckoutHere? checkout;

  /// The branch the checkout is on, where the work starts in the repository the checkout is of: the machine cannot
  /// see a checkout here, so it is told. Null for a detached checkout or another repository, which start as the
  /// machine decides.
  String? get checkoutBranch {
    final here = checkout;
    final branch = here?.branch;
    if (here == null || branch == null) return null;
    if (repository != null && repository == here.repository) return branch;
    final project = this.project;
    final chosen = project?.repositoryStates.where((each) => each.name == repository).firstOrNull;
    if (project == null || chosen == null) return null;
    if (sameAddress(chosen.upstream, here.origin) || sameAddress(chosen.upstream, here.path)) return branch;
    // A project the checkout itself named, whose file names no upstream: the checkout is its one repository, or the
    // one called as the project, as the machine itself matches a checkout.
    final itself = chosen.upstream.isEmpty && (project.workRepositories.length == 1 || chosen.name == project.name);
    return here.namedTheProject && itself ? branch : null;
  }

  /// Whether a repository has to be chosen: whenever the machine named any. A machine older than
  /// repositories per project names none and is sent none.
  bool get needsARepository => (project?.workRepositories ?? const <String>[]).isNotEmpty;

  /// What an unattended run is asked to do.
  String prompt = '';

  /// The unattended run's time limit as typed, including input that still needs correction.
  String minutesText = '30';

  /// The unattended run's time limit, absent for a session or invalid input.
  int? get minutes => takesAPrompt && minutesProblem == null ? int.tryParse(minutesText) : null;

  /// Why the time limit cannot be used, absent for sessions that have no limit.
  String? get minutesProblem {
    if (!takesAPrompt) return null;
    final number = int.tryParse(minutesText);
    // The contract's int is 32 bits: a larger number would reach the machine as another one.
    return RegExp(r'^[0-9]+$').hasMatch(minutesText) && number != null && number >= 1 && number <= 2147483647
        ? null
        : 'Enter a whole number of minutes, from 1 to 2147483647.';
  }

  /// Takes the time limit typed for unattended work.
  void allowMinutes(String typed) {
    minutesText = typed;
    notifyListeners();
  }

  /// The model the work runs, as the field holds it: the default for the provider the machine names, one typed, one
  /// carried over from the task it goes on with, or empty. Sent only when not empty: absent, the machine takes the
  /// provider's default, else the agent's own.
  String model = '';

  /// Whether [model] was typed or carried over from a task, rather than taken from a default.
  bool _modelChosen = false;

  /// Whether [model] is the one the task it goes on with ran.
  bool _modelCarried = false;

  /// The provider [model] is for, or empty while none is known.
  String _modelFor = '';

  /// The agent [model] was typed or carried over under, the person's pick (null where the machine chooses): a model
  /// typed before the machine named a provider is taken for the provider of that agent alone.
  String? _modelAgent;

  /// What became of a model chosen for one provider when the machine named another, or null.
  String? modelWords;

  /// The default model for the provider the machine names for this start: the repository's, else the project's;
  /// null where none is named or no provider is known.
  ProviderModel? get defaultModel {
    final provider = readiness?.provider ?? '';
    final where = project;
    if (where == null || provider.isEmpty) return null;
    final repository = where.repositoryStates.where((each) => each.name == this.repository).firstOrNull;
    return ProviderModel.forProvider(repository?.defaultModels ?? const <ProviderModel>[], provider) ??
        ProviderModel.forProvider(where.defaultModels, provider);
  }

  /// What the model field says of what it holds, for a person.
  String get modelHelp {
    final provider = readiness?.provider ?? '';
    final fallback = defaultModel;
    if (model.isEmpty) {
      if (provider.isEmpty) {
        return 'Left empty, the machine takes the default model of the provider it uses, else the agent’s own. '
            'It has not said which provider that is yet.';
      }
      return fallback == null
          ? 'The agent’s own default: neither the repository nor the project names one for $provider.'
          : 'Left empty, the machine takes ${fallback.shown}, the default for $provider ${_whence(fallback)}.';
    }
    if (_modelCarried) return 'The model it ran last time${_modelFor.isEmpty ? '' : ', through $_modelFor'}.';
    if (!_modelChosen && fallback != null && fallback.model == model) {
      return '${fallback.shown}, the default for $provider ${_whence(fallback)}. Change it if you like.';
    }
    return _modelFor.isEmpty ? 'As typed.' : 'As typed, for $_modelFor.';
  }

  static String _whence(ProviderModel named) => switch (named.from) {
    'repository' => 'from the repository',
    'project' => 'from the project',
    '' => 'on the machine',
    final other => 'from $other',
  };

  /// Takes what was typed as the model. Emptied, it follows the provider's default again.
  void chooseModel(String typed) {
    model = typed.trim();
    _modelChosen = model.isNotEmpty;
    _modelCarried = false;
    // The answer on screen is about the agent chosen now, or there is none yet: never the agent before's provider.
    _modelFor = readiness?.provider ?? '';
    _modelAgent = agent;
    modelWords = null;
    notifyListeners();
  }

  /// Fits the model to the provider the machine now names: a default follows it, and a model chosen for another
  /// provider is cleared, with a word, rather than sent where it means nothing.
  void _fitTheModel() {
    final provider = readiness?.provider ?? '';
    final fallback = defaultModel;
    if (!_modelChosen) {
      // No provider known: none, rather than a default of a provider that may not run.
      model = fallback?.model ?? '';
      _modelFor = provider;
      return;
    }
    // An answer that names no provider says nothing about the model: kept as it is.
    if (provider.isEmpty || _modelFor == provider) return;
    // Typed before any provider was named: it is that agent's, and taken only for an answer about it.
    if (_modelFor.isEmpty && _modelAgent == agent) {
      _modelFor = provider;
      return;
    }
    modelWords =
        '$model was for ${_modelFor.isEmpty ? 'another agent' : _modelFor}; the model is '
        '${fallback == null ? 'the agent’s own default' : fallback.shown} now.';
    model = fallback?.model ?? '';
    _modelChosen = false;
    _modelCarried = false;
    _modelFor = provider;
  }

  /// Starts the model afresh: [carried] from a task, or none until the machine names a provider.
  void _forgetTheModel({String carried = '', String provider = ''}) {
    model = carried;
    _modelChosen = carried.isNotEmpty;
    _modelCarried = carried.isNotEmpty;
    _modelFor = carried.isEmpty ? '' : provider;
    _modelAgent = agent;
    modelWords = null;
  }

  /// What to call the work, or empty to let the machine name it.
  ///
  /// Optional on purpose: `Start` names a task when nothing else does, and a name somebody had to
  /// invent before they could begin is a question asked at the worst moment.
  String name = '';

  /// Whether the person typed the name, rather than taking the one suggested.
  bool _named = false;

  /// The names of the project's tasks on the machine, which a suggested name never reuses.
  Set<String> _taken = const <String>{};

  /// Fills the name in from the repository (a task's name is required, and
  /// an unnamed start was called `shell`, which read as the wrong mode): its name, made one a task
  /// can have, and numbered on where a task of the project has it already. Never over a typed one.
  void _suggestAName() {
    if (_named || continuing != null) return;
    name = suggestedTaskName(repository ?? project?.name ?? '', _taken);
  }

  /// The task being continued, or null when this is new work.
  Task? continuing;

  /// The existing task whose name this reviewed restart may reuse.
  Task? restarting;

  /// The template this was opened from, or null when it was not.
  Template? from;

  /// What to call this job if it is kept as a template.
  String templateName = '';

  /// The vault's entries, by name, or empty while the vault cannot be read.
  List<Credential> vaultEntries = const <Credential>[];

  /// The destinations this machine declares, or null when it cannot list them.
  List<Destination>? destinations;

  /// The model providers this machine declares, which a vault entry can be given for as well.
  List<Provider> providers = const <Provider>[];

  /// The credentials this work is given beyond what its project names: a vault entry's name to
  /// the destination it is for. **Never chosen for somebody**, and emptied whenever it is opened.
  Map<String, String> credentials = const <String, String>{};

  /// Gives the work [entry] for [destination], replacing what that entry was for before.
  void grant(String entry, String destination) {
    credentials = <String, String>{...credentials, entry: destination};
    _askAgainAboutCredentials();
  }

  /// Takes [entry] away from the work again.
  void withdraw(String entry) {
    credentials = <String, String>{...credentials}..remove(entry);
    _askAgainAboutCredentials();
  }

  /// Asked again, not kept: whether work can start turns on what it is given.
  void _askAgainAboutCredentials() {
    readiness = null;
    notifyListeners();
    final machine = _machine;
    if (machine != null) unawaited(_askWhetherItCanStart(machine));
  }

  /// How long to wait before asking once more whether work can start, where the machine refused an
  /// agent it lists.
  static Duration askAgainAfter = const Duration(seconds: 2);

  bool _askedAgain = false;

  /// Asks the forge kept here which host keys it publishes for itself; set by whoever opens the form,
  /// null where no forge is kept. Read only when a start is refused for a host the machine never met.
  Future<List<String>> Function()? publishedHostKeys;

  /// The other machines where work of the same project runs, as the window last heard; set by
  /// whoever opens the start, which sees every machine.
  List<String> runningElsewhere = const <String>[];

  /// What starting here means for talking to the project's work elsewhere, or null where nothing:
  /// work on two machines shares a conversation only through a central Matrix server.
  /// The machine says whether the project names one: what its messages
  /// `reaches` on loopback is the machine's own homeserver, which no other machine reaches, and an
  /// offline project (`loopbackOnly`) stays there. A central one is not joined by a second machine
  /// yet either, and is said so rather than promised.
  String? get apartFromElsewhere {
    final messages = project?.messages;
    if (runningElsewhere.isEmpty || messages == null) return null;
    final where = runningElsewhere.length == 1
        ? runningElsewhere.single
        : '${runningElsewhere.sublist(0, runningElsewhere.length - 1).join(', ')} and ${runningElsewhere.last}';
    final name = project?.name ?? 'this project';
    // The machine's own homeserver is reached on loopback; an offline project must stay there.
    final ownHomeserver =
        messages.loopbackOnly ||
        messages.reaches.isEmpty ||
        messages.reaches.every((each) => RegExp(r'^(https?://)?(127\.|localhost\b|\[::1\])').hasMatch(each));
    if (ownHomeserver) {
      return 'Work of $name runs on $where already. Work on different machines can talk to each other only '
          "through a central Matrix server, and this project names none: each machine's own homeserver keeps "
          'its conversation to that machine. Start this work on $where for the two to talk.';
    }
    return "Work of $name runs on $where already. The project's conversation is on a central Matrix server, "
        'but a second machine cannot join it yet. Start this work on $where for the two to talk.';
  }

  /// The fingerprints the forge publishes, once asked; empty where it was not or could not be.
  List<String> published = const <String>[];

  /// The key the host offers that the forge publishes too, where the machine never met the host:
  /// trusted from here with one press, as binding a machine does.
  HostKey? get publishedOffer => readiness?.outcome.name != 'UNKNOWN_HOST_KEY'
      ? null
      : readiness!.hostKeys.where((each) => published.contains(each.fingerprint)).firstOrNull;

  /// Trusts the key the forge publishes for the host, then asks again whether work can start.
  Future<void> trustThePublishedKey() async {
    final offer = publishedOffer;
    final host = readiness?.host ?? '';
    final machine = _machine;
    if (offer == null || host.isEmpty || machine == null) return;
    final opening = _opening;
    try {
      final trusted = await machine.trustHostKey(host, offer.fingerprint);
      if (opening != _opening) return;
      if (!trusted.recorded) problem = trusted.detail.isEmpty ? 'Nothing was recorded.' : trusted.detail;
    } on VarlinkException catch (refusal) {
      if (opening != _opening) return;
      problem = _refused(refusal, 'trusting $host’s key');
    }
    readiness = null;
    notifyListeners();
    await _askWhetherItCanStart(machine);
  }

  /// Whether an allowance is on its way to the machine, so that it is not sent twice.
  bool allowing = false;

  /// Allows what the repository's `porelo.yml` sets, exactly as shown, then asks again whether work can start.
  Future<void> allowTheSettings() async {
    final shown = readiness;
    final repository = this.repository;
    final machine = _machine;
    if (allowing || shown == null || shown.outcome != StartOutcome.settingsNotAllowed) return;
    if (shown.settingsHash.isEmpty || repository == null || machine == null) return;
    allowing = true;
    problem = null;
    notifyListeners();
    final opening = _opening;
    try {
      final allowed = await machine.allowSettings(repository, shown.settingsHash);
      if (opening != _opening) return;
      if (!allowed.allowed) {
        problem = allowed.outcome == 'CHANGED'
            ? 'porelo.yml changed after it was shown, so nothing was allowed. Read what it sets now.'
            : (allowed.detail.isEmpty ? 'Nothing was allowed (${allowed.outcome}).' : allowed.detail);
      }
    } on VarlinkException catch (refusal) {
      if (opening != _opening) return;
      problem = _refused(refusal, "allowing $repository's settings");
    } finally {
      allowing = false;
    }
    if (opening != _opening) return;
    readiness = null;
    notifyListeners();
    await _askWhetherItCanStart(machine);
  }

  /// Whether the agent list is being read.
  bool busy = false;

  /// Why it could not be read or started, in words.
  String? problem;

  /// Whether work can start here, as the daemon answers it. Null until it has been asked.
  ///
  /// Asked when the dialog opens and again when the agent changes, never cached for the session:
  /// what it answers turns on what the vault holds, and that changes without anything else
  /// changing.
  Readiness? readiness;

  /// Whether a prompt belongs with the chosen mode.
  ///
  /// Only with `UNATTENDED`. The backend accepts `SHELL` with a prompt and records `SHELL`, which
  /// would say a person is driving a run nobody is attached to — so the combination is not
  /// offered rather than sent and regretted.
  bool get takesAPrompt => mode == Mode.unattended;

  /// Whether there is enough to start with.
  ///
  /// An unattended run with no prompt is the one combination that would start something and then
  /// have nothing for it to do.
  bool get ready =>
      !_asking &&
      project != null &&
      agentToRun != null &&
      mode != null &&
      (!needsARepository || repository != null) &&
      (!takesAPrompt || prompt.trim().isNotEmpty) &&
      minutesProblem == null &&
      nameProblem == null &&
      (continuing != null || name.isNotEmpty) &&
      !refusedOutright &&
      !needsASignIn &&
      !signIn.holdsTheStart &&
      !(_canStartFailed && signIn.served != false);

  /// Whether the machine's answer to whether work can start says what the agent signs in with is missing, for an
  /// agent of the machine's own sign-in or not: that answer wins for a start.
  bool get _canStartWantsASignIn =>
      readiness != null &&
      const <String>{'CREDENTIAL_MISSING', 'CREDENTIAL_UNUSABLE'}.contains(readiness!.outcome.name) &&
      !readinessIsAboutTheName &&
      !readinessIsAboutTheRepository;

  /// Keeps the sign-in on the agent that would run, on the machine the form was opened on: asked again whenever
  /// that agent changes, and dropped while none is known.
  Future<void> _followTheAgent() async {
    final who = agentToRun;
    final on = _machine;
    if (who == null || on == null) {
      if (signIn.agent != null) signIn.forget();
      return;
    }
    if (signIn.agent != who || !identical(signIn.on, on)) {
      final listed = agents.where((each) => each.name == who).firstOrNull;
      await signIn.ask(on, agent: who, label: listed?.label ?? '');
    }
    // After the asking, which drops what was held before: the machine's answer for a start wins.
    if (signIn.agent == who && identical(signIn.on, on)) signIn.heldByCanStart = _canStartWantsASignIn;
  }

  /// Whether the agent chosen has nothing to sign in with yet, and can sign in from here.
  ///
  /// **Then no start of any kind**: a shell is the one start Porelo lets
  /// through without a credential, and a new person who pressed "Start it" landed in a container
  /// where the agent said "Not logged in". The sign-in comes first.
  bool get needsASignIn =>
      (chosenAgent?.canLogIn ?? false) &&
      readiness != null &&
      const <String>{'CREDENTIAL_MISSING', 'CREDENTIAL_UNUSABLE'}.contains(readiness!.outcome.name) &&
      !readinessIsAboutTheName &&
      !readinessIsAboutTheRepository;

  /// Why the name cannot be a task's, or null when it can or none was typed: [taskNameProblem],
  /// then the machine's own refusal.
  String? get nameProblem => _localNameProblem ?? _refusedName;

  /// The machine's own refusal of the name, when it answered for the name on screen.
  ///
  /// **Its words, not ours**: they carry the rule as it is on that machine and a name that would do.
  String? get _refusedName {
    final answer = readiness;
    if (name.isEmpty || answer == null || _readinessName != name) return null;
    if (answer.outcome != StartOutcome.badTaskName) return null;
    return answer.detail.isEmpty ? 'This is not a name a task can have.' : answer.detail;
  }

  /// Whether what the machine last said is about the name rather than about starting at all.
  bool get readinessIsAboutTheName => readiness?.outcome == StartOutcome.badTaskName;

  // A start under a name the project has means *that* work again, so new work never takes one
  // (walk 9: said at once, not only when it is started).
  String? get _localNameProblem => taskNameProblem(
    name,
    project: project?.name,
    taken: continuing != null ? const <String>{} : _taken.difference(<String>{?restarting?.task}),
  );

  /// Whether starting would be refused before anything was created.
  ///
  /// **Only for an unattended run.** One that cannot authenticate is certain to be wasted and
  /// nobody is watching it, so the daemon refuses it outright — and a button that is going to be
  /// refused is better not offered. The interactive modes are offered anyway: a person is right
  /// there, may know something this does not, and the cost is said rather than hidden.
  bool get refusedOutright =>
      refusedForADestination ||
      takesAPrompt &&
          readiness != null &&
          !readiness!.ready &&
          !readinessIsAboutTheName &&
          !readinessIsAboutTheRepository;

  /// Whether a credential is for a destination the machine does not declare. **Refused in every
  /// mode**: `Start` answers it with `NoSuchDestination` before anything exists, so there is
  /// nothing to offer anyway, unlike a credential missing from the vault.
  ///
  /// So are settings of the repository's `porelo.yml` this machine has not allowed, or that nobody who may sign
  /// signed: the allowance or the signature is the decision, and a start around it would be one nobody made.
  bool get refusedForADestination => switch (readiness?.outcome) {
    StartOutcome.unknownDestination || StartOutcome.settingsNotAllowed || StartOutcome.settingsUnsigned => true,
    _ => false,
  };

  /// Whether the machine's answer is only that a repository has to be chosen — **the dialog's own
  /// required choice**, never a refusal, and never a reason to warn about what starting costs.
  bool get readinessIsAboutTheRepository => readiness?.outcome == StartOutcome.noRepositoryChosen && needsARepository;

  /// What starting would cost when it is offered in spite of a problem.
  ///
  /// Measured on the Porelo side rather than guessed: a missing credential does not stop a launch.
  /// It prints one line and starts anyway, the agent fails to authenticate from inside, and a
  /// failed run is **kept** — so what is left is a container and a workspace to clear up by hand.
  String? get whatItWouldCost {
    final answer = readiness;
    if (answer == null ||
        answer.ready ||
        takesAPrompt ||
        refusedForADestination ||
        readinessIsAboutTheName ||
        readinessIsAboutTheRepository) {
      return null;
    }
    // A shell starts without the grant: the person driving it is there, and what cannot be reached
    // yet is all it costs. Not a failed run to clear up.
    if (answer.outcome == StartOutcome.authorizationNeeded) {
      return 'It starts, and ${answer.credential} is not granted, so nothing in it can use that '
          'until somebody grants it.';
    }
    return 'This will start a container you will have to clear up: the agent cannot '
        'authenticate, and a run that fails is kept rather than removed.';
  }

  /// Why work cannot be started in this project, or null when it can.
  static String? whyNot(Project? project) {
    if (project == null) return 'no project is selected';
    if (project.carried) return null;
    if (!project.canBeActedOn) {
      return '${project.name} is not on this machine';
    }
    return null;
  }

  /// Why this task cannot be continued, or null when it can.
  ///
  /// Continuing means starting the next run with the last one's prompt, extended. Three things
  /// have to be true and each of them is a different reason to say no.
  static String? whyNotContinue(Task? task) {
    if (task == null) return 'no work is selected';
    if (task.running) return 'it is still running';
    if (task.mode != Mode.unattended) {
      return 'only an unattended run is continued with a prompt';
    }
    if (task.prompt.isEmpty) {
      return 'nothing recorded what it was asked to do';
    }
    return null;
  }

  /// Opens it on a project, prefilled from a recurring job somebody named.
  ///
  /// The prompt is put in the box rather than sent as it stands: a template carries the shape of
  /// a job, and the one thing that changes between two runs of the same job is what it is asked
  /// to do this time.
  Future<void> openFrom(FleetBackend backend, Project project, Template template) async {
    this.project = project;
    openedForRepository = null;
    checkout = null;
    _offerEvery();
    // Where the job was named to start — unless the project no longer has that repository, when
    // it is chosen again rather than sent to be refused.
    repository = project.workRepositories.contains(template.repository) ? template.repository : null;
    continuing = null;
    restarting = null;
    from = template;
    templateName = template.name;
    agent = template.agent;
    mode = template.mode;
    prompt = template.prompt;
    name = '';
    problem = null;
    _forgetTheModel();
    _forgetReadiness();
    notifyListeners();
    await _reading(backend);
  }

  /// Opens it on a project, and reads what agents the machine has.
  Future<void> open(FleetBackend backend, Project project, {String? repository, CheckoutHere? checkout}) async {
    this.project = project;
    openedForRepository = repository;
    this.checkout = checkout;
    this.repository = repository;
    _offerEvery();
    continuing = null;
    restarting = null;
    from = null;
    templateName = '';
    agent = null;
    // The agent attached, with the person in its session: a first start
    // lands in Claude Code, not in a shell to type it into. A shell is a choice somebody makes.
    mode = Mode.agent;
    prompt = '';
    name = '';
    _named = false;
    _taken = const <String>{};
    problem = null;
    _forgetTheModel();
    _forgetReadiness();
    _suggestAName();
    notifyListeners();
    await _reading(backend);
    // A project with one repository to work in has nothing to choose: asked anyway, right after
    // the person chose it in the dialog before, it read as asked twice.
    if (this.project == project && offeredRepositories.length == 1 && this.repository == null) {
      chooseRepository(offeredRepositories.single);
    }
  }

  /// Opens it to continue [task], carrying over what the last run was asked to do.
  ///
  /// The old prompt is put in the box rather than sent as it stands: continuing means asking for
  /// something more, and what that is only a person knows.
  Future<void> continueFrom(FleetBackend backend, Project project, Task task) =>
      _openFromTask(backend, project, task, mode: Mode.unattended, name: '');

  /// Opens a listed task's start for review, keeping its identity and reported mode.
  Future<void> restartFrom(FleetBackend backend, Project project, Task task) =>
      _openFromTask(backend, project, task, mode: task.mode, name: task.task, restarting: true);

  Future<void> _openFromTask(
    FleetBackend backend,
    Project project,
    Task task, {
    required Mode mode,
    required String name,
    bool restarting = false,
  }) async {
    this.project = project;
    openedForRepository = null;
    checkout = null;
    _offerEvery();
    // Continued where it worked: the same repository, not a new choice.
    repository = project.repositoryOf(task);
    continuing = restarting ? null : task;
    this.restarting = restarting ? task : null;
    from = null;
    templateName = '';
    agent = task.agent.isEmpty ? null : task.agent;
    this.mode = mode;
    prompt = task.prompt;
    this.name = name;
    _named = name.isNotEmpty;
    problem = null;
    // The model it ran, so going on with it never quietly changes it to a default.
    _forgetTheModel(carried: task.model ?? '', provider: task.provider);
    _forgetReadiness();
    notifyListeners();
    await _reading(backend);
  }

  /// Closes it.
  void close() {
    // Whatever is still out for this form lands nowhere, and nothing more is asked of its machine.
    _forgetReadiness();
    _machine = null;
    project = null;
    repository = null;
    openedForRepository = null;
    checkout = null;
    continuing = null;
    restarting = null;
    _offerEvery();
    notifyListeners();
  }

  /// Chooses the agent, or leaves it to the machine, and asks again whether work can start.
  ///
  /// Asked again rather than kept: what `CanStart` answers turns on which agent was chosen, and
  /// an answer from the previous one is worse than none.
  void chooseAgent(String? name) {
    agent = name;
    _agentIsGone = false;
    readiness = null;
    // A default went with the agent before; one typed stays, tied to the agent it was typed for.
    if (!_modelChosen) {
      model = '';
      _modelFor = '';
    }
    unawaited(_followTheAgent());
    notifyListeners();
    final machine = _machine;
    if (machine != null) unawaited(_askWhetherItCanStart(machine));
  }

  /// Chooses the repository the work starts in.
  void chooseRepository(String name) {
    repository = name;
    _suggestAName();
    readiness = null;
    notifyListeners();
    // Asked again: what the machine answers turns on which repository was chosen.
    final machine = _machine;
    if (machine != null) unawaited(_askWhetherItCanStart(machine));
  }

  /// Chooses how somebody is involved.
  void chooseMode(Mode chosen) {
    mode = chosen;
    notifyListeners();
  }

  /// Takes what was typed as the template's name.
  void callTheTemplate(String typed) {
    templateName = typed.trim();
    notifyListeners();
  }

  /// What would be kept as a template, or null when there is not enough to keep.
  ///
  /// Built from what is on screen rather than from what a template was opened with, so keeping a
  /// job after editing it keeps what was edited.
  Template? get asTemplate {
    final where = project;
    // By name, the machine's choice too: a job kept is the agent seen here, not whichever is signed in later.
    final which = agentToRun;
    final how = mode;
    if (where == null || which == null || how == null || templateName.isEmpty) return null;
    return Template(
      name: templateName,
      project: where.name,
      agent: which,
      mode: how,
      prompt: takesAPrompt ? prompt.trim() : '',
      repository: repository ?? '',
    );
  }

  /// Takes what was typed as the name, and asks the machine about it once nothing here objects.
  void callIt(String typed) {
    name = typed.trim();
    // Typed by the person: no longer replaced by a suggestion when the repository changes.
    _named = name.isNotEmpty;
    notifyListeners();
    final machine = _machine;
    if (machine != null && _localNameProblem == null) unawaited(_askWhetherItCanStart(machine));
  }

  /// Takes what was typed as the thing to ask for.
  void ask(String typed) {
    prompt = typed;
    notifyListeners();
  }

  /// What to call the operation this starts, for somebody reading the list an hour later.
  String get title => switch (mode) {
    Mode.unattended when continuing != null => 'Continue ${continuing!.shown}',
    Mode.unattended => 'Run ${agentToRun ?? 'an agent'} in ${project?.name ?? ''}',
    _ => 'Start work in ${project?.name ?? ''}',
  };

  /// The stream the operation is built on. Empty when there is not enough to start with.
  Stream<StartEvent> begin(FleetBackend backend) => ready ? _startOn(backend)() : const Stream<StartEvent>.empty();

  /// The start as the form holds it at the press, on the machine it was opened on; null when there is not enough to
  /// start with.
  ///
  /// **Taken at the press**: the form closes as Start is pressed, and a question put before the start (the
  /// machine's proposal for a first task) is answered after that, so what is sent then is what was pressed, and
  /// never to the machine chosen meanwhile.
  StartPress? press() {
    final on = _machine;
    final where = project;
    if (!ready || on == null || where == null) return null;
    return StartPress(
      on: on,
      title: title,
      project: where.name,
      named: name.trim(),
      mode: mode!,
      repository: repository,
      fromACheckout: checkout != null,
      agent: agentToRun,
      signsIn: signIn.served == true,
      send: _startOn(on),
    );
  }

  /// The `Start` of what the form holds now, sent to [backend] when called.
  Stream<StartEvent> Function() _startOn(FleetBackend backend) {
    final task = name.isEmpty ? null : name;
    final project = this.project!.name;
    final agent = this.agent;
    final mode = this.mode;
    // Only with `UNATTENDED`, and trimmed: a prompt of spaces is not a prompt.
    final prompt = takesAPrompt ? this.prompt.trim() : null;
    final minutes = this.minutes;
    final repository = this.repository;
    final credentials = this.credentials;
    final from = checkoutBranch;
    // Only when there is one: absent, the machine takes the provider's default or the agent's own.
    final model = this.model.isEmpty ? null : this.model;
    return () => backend.startTask(
      task: task,
      project: project,
      agent: agent,
      mode: mode,
      prompt: prompt,
      minutes: minutes,
      repository: repository,
      credentials: credentials,
      from: from,
      model: model,
    );
  }

  /// The machine the form was opened on, by the backend it asks, or null before it was opened.
  FleetBackend? get openedOn => _machine;

  /// The machine this was opened against, so choosing an agent can ask it again.
  FleetBackend? _machine;

  /// The name the last answer was about, or null when none was sent.
  String? _readinessName;

  /// Drops the answer about what was open before, and any question about it still out: an answer
  /// about another project, or one this machine is too old to give, is worse than none.
  void _forgetReadiness() {
    _opening++;
    _agentIsGone = false;
    readiness = null;
    _readinessName = null;
    _canStartFailed = false;
    _asked++;
    // A sign-in of the start before goes on in its own task; only its wait is dropped.
    signIn.forget();
  }

  /// Counts the questions, so an answer to an earlier one never overwrites a later one.
  int _asked = 0;

  /// Counts the openings and closings, so an answer for a form opened earlier lands nowhere.
  int _opening = 0;

  /// The questions still out. **Nothing starts on them**: a start in that moment skips what the answer
  /// was about to say, a missing sign-in among it, and with no agent picked it would have no choice to show.
  int _questionsOut = 0;

  bool get _asking => _questionsOut > 0;

  /// Whether the machine failed to say whether work can start, the last it was asked. On a machine with sign-ins of
  /// its own that answer wins for a start, so **a failed one holds it**, whatever an earlier answer or the sign-in
  /// says.
  bool _canStartFailed = false;

  /// The agent chosen, the person's or the machine's, as the machine listed it, or null.
  Agent? get chosenAgent => agents.where((each) => each.name == agentToRun).firstOrNull;

  /// Whether the machine settled the agent, with nobody having picked one.
  ///
  /// **Only where it says how it chose**: a machine older than `agentSource` may name an agent it did not
  /// choose this way, and there the person picks, rather than this guessing.
  ///
  /// A missing carried-over agent stays the person's to replace until they explicitly return the choice to the machine.
  bool get machineChose =>
      agent == null && !_agentIsGone && (readiness?.agent.isNotEmpty ?? false) && readiness!.agentSource.isNotEmpty;

  /// Whether the field may say that the machine chooses: until the machine has answered, and then if it did.
  bool get machineMayChoose => agent == null && !_agentIsGone && (readiness == null || machineChose);

  /// Whether the agent carried over from a finished run is no longer installed, so the person picks another.
  bool _agentIsGone = false;

  /// The agent that would run: the one picked, else the one the machine chose, else none yet.
  String? get agentToRun => agent ?? (machineChose ? readiness!.agent : null);

  /// The agents to pick from, the ones found signed in first and otherwise in the machine's order.
  List<Agent> get agentsInOrder {
    final signedIn = readiness?.signedIn ?? const <String>[];
    bool first(Agent each) => each.found == 'SIGNED_IN' || signedIn.contains(each.name);
    return <Agent>[...agents.where(first), ...agents.where((each) => !first(each))];
  }

  /// Which agent the machine chose and why, in words, or null when it chose none.
  String? get machineChoice {
    if (!machineChose) return null;
    final answer = readiness!;
    final who = chosenAgent?.label.isNotEmpty ?? false ? chosenAgent!.label : answer.agent;
    return switch (answer.agentSource) {
      'SIGNED_IN' =>
        'The machine chooses $who: it was found signed in'
            '${answer.provider.isEmpty ? '' : ' to ${answer.provider}'}'
            '${answer.agentFoundIn.isEmpty ? '' : ', in ${answer.agentFoundIn}'}.',
      'PROJECT' => 'The machine chooses $who: the repository names it.',
      'ONLY_ONE' => 'The machine chooses $who: it is the only one installed.',
      final other => 'The machine chooses $who ($other).',
    };
  }

  /// Asks the machine again whether work can start — after something was done about why not.
  Future<void> askAgain() async {
    final machine = _machine;
    // A sign-in that holds the start for what was dealt with (a shut vault, a refusal) is asked again with it; one
    // signed in, or one that runs, is kept.
    if (!signIn.signedIn && !signIn.running && !signIn.starting) signIn.forget();
    if (machine != null) await _askWhetherItCanStart(machine);
  }

  /// Asks the daemon whether work can start, without starting anything.
  ///
  /// **The name goes with it only when nothing here objects to it**: a name refused on this side is
  /// already said, and asking about it would only put the machine's copy of the same sentence
  /// beside it.
  Future<void> _askWhetherItCanStart(FleetBackend backend) async {
    final where = project;
    if (where == null || !where.canBeActedOn) return;
    final asking = ++_asked;
    final about = name.isEmpty || _localNameProblem != null ? null : name;
    _questionsOut++;
    try {
      final answer = await backend.canStart(
        project: where.name,
        agent: agent,
        task: about,
        repository: repository,
        credentials: credentials,
      );
      // Typing moves faster than a machine answers.
      if (asking != _asked) return;
      // Refused for an agent the machine lists as installed: measured on the test machine while another task
      // was starting, and gone when asked again. Asked again once, a moment later, rather than
      // leaving *Start it* off over an answer the machine itself contradicts.
      if (answer.outcome.name == 'UNKNOWN_AGENT' && !_askedAgain && agents.any((each) => each.name == agent)) {
        _askedAgain = true;
        await Future<void>.delayed(askAgainAfter);
        if (asking != _asked) return;
        return await _askWhetherItCanStart(backend);
      }
      _askedAgain = false;
      if (answer.outcome.name == 'UNKNOWN_HOST_KEY' && published.isEmpty && publishedHostKeys != null) {
        try {
          published = await publishedHostKeys!();
        } on Object {
          published = const <String>[];
        }
        if (asking != _asked) return;
      }
      readiness = answer.naming(agent);
      _readinessName = about;
      _canStartFailed = false;
      _fitTheModel();
      // Asked before the question counts as answered: nothing starts while the sign-in is not read.
      await _followTheAgent();
    } on VarlinkDisconnected {
      // Nothing to say: the dialog already shows what it could not read, and a second sentence
      // about the same lost connection is noise at the moment somebody is trying to work.
      if (asking == _asked) {
        _canStartFailed = true;
        await _followTheAgent();
      }
    } on FeatureNotSupported {
      // A backend older than `CanStart`. Nothing is claimed either way, which is what leaving it
      // null means — better than asserting readiness nobody measured. The sign-in is still read.
      if (asking == _asked) {
        _canStartFailed = false;
        await _followTheAgent();
      }
    } on VarlinkException catch (refusal) {
      // The machine could not answer the question: said, never left to escape. This is asked from
      // an open dialog nobody awaits, so an error let through here reaches nobody at all.
      if (asking == _asked) {
        problem = _refused(refusal, 'whether work can start');
        _canStartFailed = true;
        await _followTheAgent();
      }
    } finally {
      _questionsOut--;
      notifyListeners();
    }
  }

  static String _refused(VarlinkException refusal, String what) {
    final said = refusal.parameters['message'] ?? refusal.parameters['detail'];
    return said is String && said.isNotEmpty
        ? 'The machine could not say $what: $said'
        : 'The machine could not say $what (${refusal.simpleName}).';
  }

  /// Reads the vault's entries and the machine's destinations, for giving the work more than its
  /// project names. **Either may be missing without anything else failing**: a locked vault or an
  /// older machine only means no more can be given here, which the dialog says.
  Future<void> _readingWhatCanBeGiven(FleetBackend backend, int opening) async {
    var vault = const <Credential>[];
    try {
      final read = await backend.credentials();
      vault = read.readable ? read.credentials : const <Credential>[];
    } on FeatureNotSupported {
      // Nothing more can be given here.
    } on VarlinkException {
      // Nothing more can be given here.
    }
    if (opening != _opening) return;
    vaultEntries = vault;
    try {
      final declared = (await backend.providers()).providers;
      if (opening != _opening) return;
      providers = declared;
    } on FeatureNotSupported {
      if (opening == _opening) providers = const <Provider>[];
    } on VarlinkException {
      if (opening == _opening) providers = const <Provider>[];
    }
    if (opening != _opening) return;
    try {
      final declared = await backend.destinations();
      if (opening == _opening) destinations = declared;
    } on FeatureNotSupported {
      if (opening == _opening) destinations = null;
    } on VarlinkException {
      if (opening == _opening) destinations = null;
    }
  }

  Future<void> _reading(FleetBackend backend) async {
    _machine = backend;
    final opening = _opening;
    // Every opening comes through here: what was given belongs to the work it was given to, and
    // is never carried into the next.
    credentials = const <String, String>{};
    busy = true;
    minutesText = '30';
    notifyListeners();
    try {
      final answered = await backend.agentsOn();
      if (opening != _opening) return;
      final installed = answered.agents;
      final couldNotBeRead = answered.failures;
      // `Agents` answers one entry per name — they are keyed by name on the daemon side — so
      // this fold is never used. Three lines to keep a broken promise from becoming a crash:
      // `DropdownButtonFormField` asserts on two items sharing a value, which would take the
      // whole dialog down rather than shorten a list.
      final seen = <String>{};
      agents = <Agent>[
        for (final agent in installed)
          if (seen.add(agent.name)) agent,
      ];
      failures = couldNotBeRead;
      // Carried over from a finished run, and the agent may since have been removed. Saying so
      // beats a start that is refused by a name nobody can see is missing.
      if (agent != null && !installed.any((each) => each.name == agent)) {
        problem = '$agent is not installed on this machine any more.';
        agent = null;
        _agentIsGone = true;
      }
      // The names already in use in the project, as a person types them (`Task.task`, not the
      // container's name): a suggestion never reuses one, and a typed one is refused at once.
      try {
        final where = project?.name;
        final listed = await backend.tasks();
        if (opening != _opening) return;
        _taken = <String>{
          for (final task in listed)
            if (task.project == where && task.task.isNotEmpty) task.task,
        };
      } on Object {
        if (opening != _opening) return;
        _taken = const <String>{};
      }
      _suggestAName();
      await _readingWhatCanBeGiven(backend, opening);
      if (opening != _opening) return;
      await _askWhetherItCanStart(backend);
    } on VarlinkDisconnected catch (ex) {
      if (opening == _opening) problem = 'Lost contact with the machine: ${ex.message}';
    } on FeatureNotSupported catch (ex) {
      if (opening == _opening) problem = '$ex';
    } on VarlinkException catch (refusal) {
      if (opening == _opening) problem = _refused(refusal, 'which agents it has');
    } finally {
      if (opening == _opening) {
        busy = false;
        notifyListeners();
      }
    }
  }
}

/// A start as pressed: what was on the form, and the machine it was opened on.
class StartPress {
  /// Constructor taking what was pressed.
  const StartPress({
    required this.on,
    required this.title,
    required this.project,
    required this.named,
    required this.mode,
    required this.repository,
    required this.fromACheckout,
    required this.send,
    this.agent,
    this.signsIn = false,
  });

  /// The agent that runs, the person's or the machine's choice, or null where none was known.
  final String? agent;

  /// Whether the machine has sign-ins of its own, so a start refused for a missing one can offer it.
  final bool signsIn;

  /// The machine the form was opened on, by the backend it asks.
  final FleetBackend on;

  /// What to call the operation.
  final String title;

  /// The project it starts in.
  final String project;

  /// The name typed or taken, trimmed; empty where the machine names it.
  final String named;

  /// How somebody is involved.
  final Mode mode;

  /// The repository it starts in, or null.
  final String? repository;

  /// Whether it starts from a checkout on this computer.
  final bool fromACheckout;

  /// Sends the `Start`, to [on].
  final Stream<StartEvent> Function() send;
}

/// A checkout on this computer that work was asked to start from: the branch it is on, null where it is detached,
/// and the address of its origin.
class CheckoutHere {
  /// Constructor taking what was read of it.
  const CheckoutHere({
    required this.branch,
    required this.origin,
    this.path = '',
    this.repository,
    this.namedTheProject = false,
  });

  /// The branch the checkout is on, or null where it is on none.
  final String? branch;

  /// Its origin's address, as git names it, or empty where it names none.
  final String origin;

  /// Its folder on this computer, which a project's file may name as its upstream where it has no origin.
  final String path;

  /// The repository it was put in as, by name, or null where it was not put in from here.
  final String? repository;

  /// Whether the project work starts in is the one this checkout's own file or plugins named.
  final bool namedTheProject;

  /// The same checkout, put in as [name].
  CheckoutHere putInAs(String name) =>
      CheckoutHere(branch: branch, origin: origin, path: path, repository: name, namedTheProject: namedTheProject);

  /// The same checkout, as the one that named the project work starts in.
  CheckoutHere get naming =>
      CheckoutHere(branch: branch, origin: origin, path: path, repository: repository, namedTheProject: true);
}

/// Whether two addresses name one repository, as the machine's own `RepositoryAddress.sameUpstream` judges it: host,
/// port and the whole path agree, whatever the scheme, the user, a port that is its scheme's own, a trailing `.git` or
/// `/` and the host's case; a path on this computer only ever matches the same path.
bool sameAddress(String one, String other) {
  final left = _upstreamKey(one);
  return left != null && left == _upstreamKey(other);
}

String? _upstreamKey(String address) {
  final trimmed = address.trim();
  if (trimmed.isEmpty) return null;
  String path(String raw) =>
      raw.replaceFirst(RegExp(r'^/+'), '').replaceFirst(RegExp(r'/+$'), '').replaceFirst(RegExp(r'\.git$'), '');
  final scheme = trimmed.indexOf('://');
  if (scheme >= 0 && !trimmed.startsWith('file://')) {
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) return null;
    const own = <String, int>{'ssh': 22, 'https': 443, 'http': 80, 'git': 9418};
    final port = uri.hasPort && uri.port != own[uri.scheme.toLowerCase()] ? ':${uri.port}' : '';
    return 'remote ${uri.host.toLowerCase()}$port/${path(uri.path)}';
  }
  final scp = RegExp(r'^[^/@]+@([^/:]+):(.*)$').firstMatch(trimmed);
  if (scp != null) return 'remote ${scp.group(1)!.toLowerCase()}/${path(scp.group(2)!)}';
  final local = trimmed.startsWith('file://') ? trimmed.substring('file://'.length) : trimmed;
  return 'local ${local.startsWith('/') ? '/' : ''}${path(local)}';
}

/// What becomes of a start after the machine's first-start question for its repository.
enum AfterTheProposal {
  /// The start goes on: with the settings a yes wrote, or with Porelo's own.
  start,

  /// The person closed the question: nothing starts, and nothing was sent.
  startNothing,
}

/// Before the first task on [repository] in `default`, with no checkout here: the machine's proposal, put to the
/// person by [ask] (true for a yes, false for a no, null for closing it), and a yes sent for exactly the text shown.
///
/// [stillWanted] is asked after each wait: once it says no (the machine forgotten meanwhile), nothing more is sent.
Future<AfterTheProposal> askBeforeTheFirstTask(
  FleetBackend machine,
  String repository,
  Future<bool?> Function(FirstStart first) ask, {
  bool Function()? stillWanted,
}) async {
  final FirstStart first;
  try {
    first = await machine.firstStartOf(repository);
  } on FeatureNotSupported {
    return AfterTheProposal.start;
  } on VarlinkException catch (refusal) {
    // A Porelo that takes no repository here starts as it did before it could propose.
    if (refusal.name == 'org.varlink.service.InvalidParameter') return AfterTheProposal.start;
    rethrow;
  }
  // Only a question with a text a yes could name is put; anything else starts as the machine would without one.
  if (!first.asks || first.hash.isEmpty || first.refusal.isNotEmpty) return AfterTheProposal.start;
  if (!(stillWanted?.call() ?? true)) return AfterTheProposal.startNothing;
  final said = await ask(first);
  if (said == null || !(stillWanted?.call() ?? true)) return AfterTheProposal.startNothing;
  if (said) await machine.confirmFirstStartOf(repository, first.hash);
  return AfterTheProposal.start;
}
