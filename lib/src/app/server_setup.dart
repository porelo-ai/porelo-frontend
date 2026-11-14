import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:porelo_host/porelo_host.dart' show HostCheckAnswer, HostPreparationSettings;

import 'host_access.dart';
import 'host_check_run.dart';
import 'host_keys.dart' show KnownWithAnother;
import 'host_runs.dart';
import 'host_session.dart';
import 'machines.dart' show openSsh;
import 'preparation_host_key.dart';
import 'run_here.dart';
import 'server_first_login.dart';
import 'settings.dart';

/// What setting a server up as a machine asks, in the wizard's order, each page opening only once the one before
/// holds.
///
/// A change on an earlier page drops what the later pages proved from it: a new address drops the key, the root login
/// and the check; a new key drops the root login and the check; another choice drops the check.
class ServerSetup extends ChangeNotifier {
  /// Sets up with [access] and [runs]; the others replace this computer's programs in a test.
  ServerSetup({
    required this.access,
    required this.runs,
    required this.settings,
    this.hostCheck,
    this.noCheckWhy,
    this.runKeyCommand,
    this.knownWithAnother,
    this.forgetOldKey,
    this.rootLogin,
    this.runFirstLogin,
    this.startHost,
    Future<ComparedKeyPin> Function(String address, String key)? makePin,
    String? machineName,
  }) : _name = machineName ?? '',
       _makePin = makePin ?? ((address, key) => ComparedKeyPin.make(address, key));

  final Future<ComparedKeyPin> Function(String address, String key) _makePin;

  /// Who may set a machine up, and the card key root is handed to.
  final HostAccess? access;

  /// The owner of preparations, which go on when the wizard closes.
  final HostRuns? runs;

  /// Where a machine's preparation is kept.
  final Settings settings;

  /// The carried collection's check, or null where it holds none.
  final HostCheckRun? hostCheck;

  /// Why [hostCheck] is null, as porelo-host said it: no collection, an unreadable one, another digest or no check.
  final String? noCheckWhy;

  /// Runs `ssh-keyscan` and `ssh-keygen`; this computer's by default.
  final RunHere? runKeyCommand;

  /// What the person's own `known_hosts` holds for an address with another key.
  final Future<KnownWithAnother?> Function(String address, String key)? knownWithAnother;

  /// Takes an old key out of the person's `known_hosts`.
  final Future<void> Function(KnownWithAnother known)? forgetOldKey;

  /// Logs in as root through the pin with the card key.
  final Future<RootLogin> Function({required String address, required String pin, required String cardKey})? rootLogin;

  /// Runs ssh for the first login's run of the bootstrap line; this computer's by default.
  final RunHere? runFirstLogin;

  /// Starts `porelo-host`; this computer's by default.
  final StartHostCommand? startHost;

  // Page 1.
  String _name;
  bool _readingAccess = false;
  bool _proven = false;
  String? _accessProblem;

  // Page 2.
  String _address = '';
  String _firstLogin = '';
  bool _providerReady = false;
  String? _sshProblem;
  String? _answeredAt;

  // Page 3.
  PreparationHostKey? _key;
  bool _pasted = false;
  bool _fetching = false;
  String? _keyProblem;
  bool _compared = false;
  KnownWithAnother? _old;
  int _keyRequest = 0;

  // Page 4.
  HostPreparationSettings _choices = const HostPreparationSettings();

  // Page 5.
  ComparedKeyPin? _pin;
  RootLogin? _root;
  bool _tryingRoot = false;

  // Page 6.
  HostCheckAnswer? _check;
  bool _checking = false;
  int _checkRequest = 0;

  // Prepare.
  HostPreparation? _run;
  String? _prepareProblem;
  bool _preparing = false;

  /// Whether the key changed since it was compared, so the wizard goes back to the key's page.
  final keyChangedSinceCompared = ValueNotifier<bool>(false);

  /// Reads the person's identity and the organization again, before anything is offered.
  Future<void> start() async {
    final access = this.access;
    if (access == null) return;
    _readingAccess = true;
    notifyListeners();
    try {
      await access.readAgain();
      _proven = true;
    } on Exception catch (error) {
      _accessProblem = 'Your identity and the Porelo organization could not be read: $error';
    } finally {
      _readingAccess = false;
      notifyListeners();
    }
  }

  // ---- Which machine.

  /// The machine's name.
  String get name => _name;

  /// The machines this person can set up now: listed, theirs, and with no preparation of their own.
  List<String> get choices {
    final access = this.access;
    if (access == null || !_proven) return const [];
    return [
      for (final each in access.hostsOfMine)
        if (access.unavailable(each) == null &&
            settings.hostUp(each) == null &&
            !(runs?.of(each)?.running ?? false) &&
            !(runs?.of(each)?.waiting ?? false))
          each,
    ];
  }

  /// Chooses [value].
  set name(String value) {
    if (value == _name) return;
    _name = value;
    notifyListeners();
  }

  /// Why the machine's page cannot go on, or null.
  String? get whyNotMachine {
    final access = this.access;
    if (access == null) return 'This computer cannot set up a machine: it has no verified Machine Admin identity.';
    if (_readingAccess) return 'Reading your identity and the Porelo organization…';
    if (!_proven) return _accessProblem ?? 'Your identity and the Porelo organization have not been read.';
    if (_name.isEmpty) {
      if (access.unavailable() case final why?) return why;
      return choices.isEmpty
          ? 'There is no machine to set up: you are Machine Admin of none that is listed and not set up yet. An '
                'Organization Admin lists one with Add a machine on the organization\'s page.'
          : 'Choose the machine.';
    }
    if (!choices.contains(_name)) return access.unavailable(_name) ?? '$_name is set up already, or being set up.';
    return access.unavailable(_name);
  }

  // ---- Where it is.

  /// The server's address.
  String get address => _address;

  /// The provider's first login, such as `ubuntu`.
  String get firstLogin => _firstLogin;

  /// Whether the person says the provider reports the server ready.
  bool get providerReady => _providerReady;

  /// Why SSH did not answer at the last try, or null.
  String? get sshProblem => _sshProblem;

  /// Takes a new address, dropping everything proven of the old one.
  set address(String value) {
    final trimmed = value.trim();
    if (trimmed == _address) return;
    _address = trimmed;
    _answeredAt = null;
    _sshProblem = null;
    _dropKey();
    notifyListeners();
  }

  /// Takes the provider's first login.
  set firstLogin(String value) {
    final trimmed = value.trim();
    if (trimmed == _firstLogin) return;
    _firstLogin = trimmed;
    _dropRoot();
    notifyListeners();
  }

  /// Takes the person's word that the provider reports the server ready.
  set providerReady(bool value) {
    _providerReady = value;
    notifyListeners();
  }

  /// Why the address's page cannot go on before SSH is asked, or null.
  String? get whyNotWhere {
    if (_address.isEmpty) return "Give the server's address, as the provider shows it.";
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9.:-]*$').hasMatch(_address)) {
      return 'An address is a name or an IP address, without a user or a port.';
    }
    if (_firstLogin.isEmpty) return 'Give the first login the provider gave you, such as ubuntu.';
    if (!RegExp(r'^[a-z_][a-z0-9_-]*$').hasMatch(_firstLogin)) return 'A login is one word in small letters.';
    if (!_providerReady) return 'Tick that your provider reports the server ready, with its installation finished.';
    return null;
  }

  /// Asks whether SSH answers at the address; true where it does, and the key's page may open.
  Future<bool> askSsh() async {
    final asked = _address;
    _sshProblem = await whySshDoesNotAnswer(asked, run: runKeyCommand);
    if (asked != _address) return false;
    _answeredAt = _sshProblem == null ? asked : null;
    notifyListeners();
    return _sshProblem == null;
  }

  /// Whether SSH answered at the address as it stands.
  bool get sshAnswered => _answeredAt == _address && _address.isNotEmpty;

  // ---- Its SSH host key.

  /// The key to compare, fetched or pasted, with its fingerprint.
  PreparationHostKey? get key => _key;

  /// Whether the key was pasted rather than fetched.
  bool get pasted => _pasted;

  /// Whether the key is being fetched or read.
  bool get fetching => _fetching;

  /// Why the key could not be had, or null.
  String? get keyProblem => _keyProblem;

  /// Whether the person ticked that they compared the fingerprint.
  bool get compared => _compared;

  /// What the person's own `known_hosts` holds for the address with another key, or null.
  KnownWithAnother? get oldKey => _old;

  /// Takes the person's tick.
  set compared(bool value) {
    if (value == _compared) return;
    _compared = value;
    _dropRoot();
    notifyListeners();
  }

  void _dropKey() {
    _keyRequest++;
    _key = null;
    _pasted = false;
    _fetching = false;
    _keyProblem = null;
    _compared = false;
    _old = null;
    _dropRoot();
  }

  /// Fetches the key; only ever on the person's press, never as an address is typed.
  Future<void> fetchKey() async {
    if (!sshAnswered) return;
    _dropKey();
    final request = _keyRequest;
    _fetching = true;
    notifyListeners();
    try {
      final fetched = await fetchPreparationHostKey(_address, run: runKeyCommand);
      if (request != _keyRequest) return;
      final old = await knownWithAnother?.call(_address, fetched.key);
      if (request != _keyRequest) return;
      _key = fetched;
      _old = old;
    } on WorkspaceRefused catch (refused) {
      if (request == _keyRequest) _keyProblem = refused.words;
    } finally {
      if (request == _keyRequest) {
        _fetching = false;
        notifyListeners();
      }
    }
  }

  /// Takes a pasted key and computes its fingerprint the same way.
  Future<void> pasteKey(String value) async {
    _dropKey();
    final request = _keyRequest;
    if (value.trim().isEmpty) {
      notifyListeners();
      return;
    }
    _fetching = true;
    notifyListeners();
    try {
      final key = value.trim().split(RegExp(r'\s+')).take(2).join(' ');
      final fingerprint = await fingerprintOfPastedKey(key, run: runKeyCommand);
      if (request != _keyRequest) return;
      final old = await knownWithAnother?.call(_address, key);
      if (request != _keyRequest) return;
      _key = (key: key, fingerprint: fingerprint);
      _pasted = true;
      _old = old;
    } on WorkspaceRefused catch (refused) {
      if (request == _keyRequest) _keyProblem = refused.words;
    } finally {
      if (request == _keyRequest) {
        _fetching = false;
        notifyListeners();
      }
    }
  }

  /// Why the key's page cannot go on, or null.
  String? get whyNotKey {
    if (_fetching) return 'Fetching the SSH host key…';
    if (_key == null) return _keyProblem ?? 'Fetch the SSH host key, or paste it.';
    if (!_compared) return 'Run the command on the server, compare, and tick "I compared this fingerprint".';
    return null;
  }

  /// Takes the old key out of the person's `known_hosts`, once the new one is compared and preparing starts.
  Future<bool> replaceOldKey() async {
    final old = _old;
    if (old == null) return true;
    if (!_compared) return false;
    try {
      await forgetOldKey?.call(old);
      _old = null;
      return true;
    } on Object catch (error) {
      _keyProblem = 'The old key could not be taken out: $error';
      return false;
    } finally {
      notifyListeners();
    }
  }

  // ---- What it will run.

  /// The choices.
  HostPreparationSettings get chosen => _choices;

  /// Takes [value], dropping the check made with the old choices.
  set chosen(HostPreparationSettings value) {
    _choices = value;
    _dropCheck();
    notifyListeners();
  }

  // ---- Hand the login over.

  /// The bootstrap line, once the identity was read again; null otherwise.
  String? get bootstrapLine {
    final access = this.access;
    if (access == null || !_proven) return null;
    try {
      return access.bootstrapCommand();
    } on HostAccessRefused {
      return null;
    }
  }

  /// Makes the pin of the compared key once it is first needed, and answers it.
  Future<ComparedKeyPin?> pin() async {
    final key = _key;
    if (key == null || !_compared) return null;
    return _pin ??= await _makePin(_address, key.key);
  }

  /// What the last root login came to, or null before one was tried.
  RootLogin? get root => _root;

  /// Whether root's login is being tried.
  bool get tryingRoot => _tryingRoot;

  void _dropRoot() {
    // A run or try still going answers for what was asked before; its answer is dropped when it comes.
    _loginAsked++;
    _runningBootstrap = false;
    _tryingRoot = false;
    _root = null;
    _bootstrapRun = null;
    final pin = _pin;
    _pin = null;
    if (pin != null) unawaited(pin.dispose());
    _dropCheck();
  }

  /// Logs in as root with the card key through the pin, and says what came of it.
  Future<void> tryRoot() async {
    final identity = access?.identity();
    final login = rootLogin;
    if (identity == null || login == null) {
      _root = (state: RootLoginState.noAnswer, words: 'Your Machine Admin card key could not be read.');
      notifyListeners();
      return;
    }
    if (_tryingRoot || _runningBootstrap) return;
    final asked = _loginAsked;
    _tryingRoot = true;
    // What root answers now is the word: an earlier run's refusal no longer stands beside it.
    _bootstrapRun = null;
    notifyListeners();
    RootLogin? root;
    try {
      final pinned = await pin();
      if (pinned == null) {
        root = (state: RootLoginState.noAnswer, words: 'Compare the SSH host key first.');
        return;
      }
      root = await login(address: _address, pin: pinned.file.path, cardKey: identity.key);
    } on Exception catch (error) {
      root = (state: RootLoginState.noAnswer, words: 'The root login could not be tried: $error');
    } finally {
      if (asked == _loginAsked) {
        _root = root;
        _tryingRoot = false;
        notifyListeners();
      }
    }
  }

  // Counts what root's login was asked for: an answer for an earlier address, login or key is not kept.
  int _loginAsked = 0;

  /// What the last *Run it for me* came to, or null before one ran.
  BootstrapRun? get bootstrapRun => _bootstrapRun;
  BootstrapRun? _bootstrapRun;

  /// Whether the bootstrap line runs by *Run it for me*.
  bool get runningBootstrap => _runningBootstrap;
  bool _runningBootstrap = false;

  /// Runs the bootstrap line on the server as the first login, unasked, through the pin; root's login follows a run
  /// that ended well. Only on the person's press: it replaces root's authorized keys.
  Future<void> runBootstrap() async {
    final line = bootstrapLine;
    if (line == null || _runningBootstrap || _tryingRoot) return;
    final asked = _loginAsked;
    _runningBootstrap = true;
    _bootstrapRun = null;
    _root = null;
    notifyListeners();
    BootstrapRun? run;
    try {
      final pinned = await pin();
      if (pinned == null) {
        run = (state: BootstrapRunState.noLogin, words: 'Compare the SSH host key first.');
        return;
      }
      final ran = await (runFirstLogin ?? runHere)(
        openSsh('ssh'),
        firstLoginRunArguments(
          pin: pinned.file.path,
          user: _firstLogin,
          address: _address,
          command: unaskedBootstrapLine(line),
        ),
      );
      run = readBootstrapRun(ran.code, ran.out, ran.err);
    } on Exception catch (error) {
      run = (state: BootstrapRunState.noLogin, words: 'The bootstrap line could not be run from here: $error');
    } finally {
      if (asked == _loginAsked) {
        _bootstrapRun = run;
        _runningBootstrap = false;
        notifyListeners();
      }
    }
    if (asked == _loginAsked && run.state == BootstrapRunState.ran) await tryRoot();
  }

  /// Why the login's page cannot go on, or null.
  String? get whyNotLogin {
    if (_runningBootstrap) return 'Running the bootstrap line on the server…';
    if (_tryingRoot) return 'Trying the root login…';
    return switch (_root) {
      null => _bootstrapRun?.words ?? 'Run the bootstrap line on the server, then try the root login.',
      (state: RootLoginState.open, words: _) => null,
      (state: _, :final words) => words,
    };
  }

  // ---- The check.

  /// The check's last answer, or null.
  HostCheckAnswer? get checkAnswer => _check;

  /// Whether the check runs.
  bool get checking => _checking;

  void _dropCheck() {
    _checkRequest++;
    _check = null;
    _checking = false;
  }

  /// Runs the reading check once.
  Future<void> runCheck() async {
    final check = hostCheck;
    final identity = access?.identity();
    final key = _key;
    if (check == null || key == null || _checking) return;
    final request = ++_checkRequest;
    _checking = true;
    _check = null;
    notifyListeners();
    final answer = identity == null
        ? const HostCheckAnswer.notAnswered('Your Machine Admin key could not be read.')
        : await check.check(address: _address, hostKey: key.key, publicKey: identity.key, settings: _choices);
    if (request != _checkRequest) return;
    _check = answer;
    _checking = false;
    notifyListeners();
  }

  /// Why the check's page cannot go on, or null.
  String? get whyNotCheck {
    if (hostCheck == null) return null;
    if (_checking) return 'The check runs. It only reads, and changes nothing on the machine.';
    return switch (_check) {
      null => 'Check the machine first. It only reads, and changes nothing on it.',
      final answer when !answer.answered => answer.said ?? 'The check gave no answer.',
      final answer when !answer.passed => 'The check found what stands in the way: the list says what to do.',
      _ => null,
    };
  }

  // ---- Prepare.

  /// The preparation started, or null.
  HostPreparation? get run => _run;

  /// Why preparing stopped, or null.
  String? get prepareProblem => _prepareProblem ?? _run?.problem;

  /// Whether the preparation is being started or runs.
  bool get preparing => _preparing || (_run?.running ?? false);

  /// Whether the machine is prepared and reachable.
  bool get prepared => _run?.ready ?? false;

  /// Starts the preparation, after fetching the key once more: a key changed since it was compared starts nothing.
  Future<void> prepare() async {
    final access = this.access;
    final runs = this.runs;
    final compared = _key;
    if (access == null || runs == null || compared == null || _preparing || _run != null) return;
    _preparing = true;
    _prepareProblem = null;
    notifyListeners();
    try {
      final machineFile = await access.machineFile(_name);
      // Put away while it read: whoever left asked to leave before anything started, so nothing starts.
      if (_disposed) return;
      if (!_pasted) {
        PreparationHostKey? now;
        try {
          now = await fetchPreparationHostKey(_address, run: runKeyCommand);
        } on WorkspaceRefused {
          // Not answering now says nothing of the key; the login holds to the one compared.
        }
        if (_disposed) return;
        if (now != null && now.key != compared.key) {
          _dropKey();
          // Said on the key's page, where the wizard goes back to.
          _keyProblem =
              "The server's SSH host key changed since you compared it, usually because its installation was still "
              'running. Nothing was started. Fetch it again and compare the new one.';
          keyChangedSinceCompared.value = true;
          return;
        }
      }
      final identity = access.identity();
      if (identity == null) throw const HostAccessRefused('Your Machine Admin card key could not be read.');
      // Only now, with the setup confirmed: going back before this leaves the person's known_hosts as it was.
      if (!await replaceOldKey()) {
        _prepareProblem = _keyProblem;
        return;
      }
      if (_disposed) return;
      final record = HostUpRecord.fromStored(
        HostUpRecord(
          hostName: _name,
          host: _name,
          givenAddress: _address,
          givenHostKey: compared.key,
          preparationSettings: _choices,
          machineFile: machineFile,
          publicKey: identity.key,
        ).stored,
      );
      if (record == null) throw const FormatException('The machine, its address and its key could not be kept.');
      final session = HostSession(executable: poreloHost(), arguments: hostArguments(record, _name), start: startHost);
      final run = _run = runs.start(project: _name, record: record, session: session, organizationReadJustNow: true);
      run.session.addListener(notifyListeners);
      notifyListeners();
      // The run is HostRuns' own and goes on after the wizard was left; this setup may be put away meanwhile.
      await run.finished;
      if (_disposed) return;
      if (!run.ready) {
        _prepareProblem = run.problem ?? 'Preparing ended without the machine ready. Its protocol below says where.';
      }
    } on HostAccessRefused catch (refused) {
      _prepareProblem = refused.words;
    } on FormatException catch (error) {
      _prepareProblem = error.message;
    } on Exception catch (error) {
      _prepareProblem = '$error';
    } finally {
      _preparing = false;
      notifyListeners();
    }
  }

  bool _disposed = false;

  /// Says nothing once put away: a preparation left running ends after the wizard that showed it.
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _run?.session.removeListener(notifyListeners);
    final pin = _pin;
    if (pin != null) unawaited(pin.dispose());
    keyChangedSinceCompared.dispose();
    super.dispose();
  }
}
