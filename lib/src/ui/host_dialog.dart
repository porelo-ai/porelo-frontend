import 'dart:async';

import 'package:flutter/material.dart';
import 'package:porelo_host/porelo_host.dart'
    show HostCheckAnswer, HostMembership, HostPreparationSettings, rootStillClosed;

import '../app/host_check_run.dart';
import '../app/host_runs.dart';
import '../app/host_access.dart';
import '../app/host_session.dart';
import '../app/machines.dart';
import '../app/host_progress.dart';
import '../app/organization_source.dart' show OrganizationRefused;
import '../app/preparation_host_key.dart';
import '../app/run_here.dart';
import '../app/session.dart';
import '../app/settings.dart';
import 'command_to_copy.dart';
import 'tokens.dart';
import 'host_check_list.dart';
import 'host_preparation_settings.dart';

/// Opens confirmed give-back of the existing rental.
Future<void> openHostTakeDownDialog(
  BuildContext context, {
  required String project,
  required Machines machines,
  required Settings settings,
  StartHostCommand? start,
  HostRuns? hostRuns,
  HostAccess? hostAccess,
  HostUpRecord? fromTheCard,
  Future<HostProgress> Function(String host)? readHostProgress,
  OpenTerminal? openTerminal,
  bool? linux,
  Future<String?> Function(String host)? removeFromOrganization,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => HostDialog(
    project: project,
    removeFromOrganization: removeFromOrganization,
    machines: machines,
    settings: settings,
    hostRuns: hostRuns,
    hostAccess: hostAccess,
    fromTheCard: fromTheCard,
    readHostProgress: readHostProgress,
    start: start,
    takeDownOnly: true,
  ),
);

/// Opens the replacement setup entry point without legacy credential inputs.
Future<void> openPrepareServerDialog(
  BuildContext context, {
  required Machines machines,
  required Settings settings,
  required HostRuns hostRuns,
  RunHere? runKeyCommand,
  String? machineName,
  HostCheckRun? hostCheck,
}) => showDialog<void>(
  context: context,
  builder: (_) => HostDialog(
    project: '',
    machines: machines,
    settings: settings,
    hostRuns: hostRuns,
    runKeyCommand: runKeyCommand,
    machineName: machineName,
    hostCheck: hostCheck,
  ),
);

/// Opens the retained public setup protocol.
Future<void> openHostRunDialog(
  BuildContext context, {
  required HostPreparation run,
  required HostRuns hostRuns,
  required Machines machines,
  Settings? settings,
  OpenTerminal? openTerminal,
}) => showDialog<void>(
  context: context,
  builder: (_) =>
      HostDialog(project: run.project, machines: machines, settings: settings, hostRuns: hostRuns, existingRun: run),
);

/// Retained setup progress and explicit rental give-back, without trust installation.
class HostDialog extends StatefulWidget {
  /// Uses the owner of setup and an injectable host process for give-back tests.
  const HostDialog({
    required this.project,
    required this.machines,
    this.settings,
    this.hostRuns,
    this.hostAccess,
    this.existingRun,
    this.start,
    this.runKeyCommand,
    this.takeDownOnly = false,
    this.removeFromOrganization,
    this.machineName,
    this.fromTheCard,
    this.hostCheck,
    this.readHostProgress,
    super.key,
  });

  /// The machine to prepare, where it is known from where this was asked.
  final String? machineName;

  /// The existing rental's stable identity.
  final String project;

  /// The watched machine list.
  final Machines machines;

  /// The rental recovery store.
  final Settings? settings;

  /// The setup owner, retained when this dialog closes.
  final HostRuns? hostRuns;

  /// Who may prepare a host, for a dialog with no setup owner.
  final HostAccess? hostAccess;

  /// The public protocol opened from its row.
  final HostPreparation? existingRun;

  /// The host process boundary.
  final StartHostCommand? start;

  /// Runs the public key scan and fingerprint command, replaceable without a network in tests.
  final RunHere? runKeyCommand;

  /// Whether the dialog confirms give-back.
  final bool takeDownOnly;

  /// Removes the machine from the organization's list once it is confirmed down; answers a refusal's words, or null.
  final Future<String?> Function(String host)? removeFromOrganization;

  /// What to take down with on a computer that kept nothing from setting it up.
  final HostUpRecord? fromTheCard;

  /// The carried collection's check, which then stands before preparing; null where the collection holds none.
  final HostCheckRun? hostCheck;

  /// The function that reads the connected host's organization status afresh before give-back.
  final Future<HostProgress> Function(String host)? readHostProgress;

  @override
  State<HostDialog> createState() => _HostDialogState();
}

class _HostDialogState extends State<HostDialog> {
  HostSession? _down;

  /// What earlier tries said stays on the machine: a later one, cut short, says it no more.
  Set<String> _notesBefore = const {};
  HostSession? _membershipSession;
  List<HostMembership>? _holders;
  bool _checkingMemberships = false;
  String? _membershipProblem;
  List<String>? _centralBlockers;
  bool _checkingCentral = false;
  bool get _centralReady => _centralBlockers?.isEmpty == true;
  final _scroll = ScrollController();
  late final _name = TextEditingController(text: widget.machineName);
  final _address = TextEditingController();
  final _hostKey = TextEditingController();
  Timer? _keyDebounce;
  int _keyRequest = 0;
  bool _fetchingKey = false;
  bool _pastedKey = false;
  bool _keyConfirmed = false;
  PreparationHostKey? _fetchedKey;
  String? _keyProblem;
  HostPreparation? _started;
  bool _startedOver = false;
  bool _busy = false;
  bool _givenBack = false;
  bool _returnedRental = false;
  String? _problem;
  final _problemShown = GlobalKey();
  String? _problemBroughtIntoView;
  HostPreparationSettings _choices = const HostPreparationSettings();
  HostCheckAnswer? _checkAnswer;
  String? _checkedFor;
  bool _checking = false;
  bool _checkAgain = false;
  int _checkRequest = 0;
  Timer? _checkDebounce;
  final _checkShown = GlobalKey();
  Settings get _settings => widget.settings ?? widget.machines.settings;
  HostUpRecord? get _record => _settings.hostUp(widget.project) ?? widget.fromTheCard;

  String _setTo(HostUpRecord record) {
    final forge = record.forge && record.preparationSettings.forge;
    return '${forge ? 'It has a forge of its own' : 'It has no forge of its own'}'
        '${forge && record.preparationSettings.kvm ? ', and runs VMs in its jobs.' : ', and runs no VMs in its jobs.'}';
  }

  /// Takes [value] as the choices, says the check must run again, and keeps them on a saved record.
  Future<void> _choose(HostPreparationSettings value) async {
    setState(() => _choices = value);
    _checkInputsMoved();
    if (_record case final saved?) {
      try {
        await _settings.rememberHostUp(widget.project, saved.withPreparationSettings(value));
      } on Exception {
        if (mounted) setState(() => _problem = 'The preparation settings could not be saved.');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _choices = _record?.preparationSettings ?? widget.existingRun?.record.preparationSettings ?? _choices;
    if (widget.takeDownOnly) {
      unawaited(_readHolders());
      unawaited(_readCentral());
      return;
    }
    // Root's bootstrap line names the card key, so it is shown only once the identity was read again.
    final access = widget.hostAccess ?? widget.hostRuns?.hostAccess;
    if (access != null) {
      _readingAccess = true;
      unawaited(_readAccess(access));
    }
  }

  bool _proven = false;
  bool _readingAccess = false;

  bool get _keyReady => _hostKey.text.trim().isNotEmpty && (_pastedKey || _fetchedKey != null && _keyConfirmed);

  void _addressChanged() {
    _keyDebounce?.cancel();
    _keyRequest++;
    setState(() {
      _fetchingKey = false;
      _keyConfirmed = false;
      _fetchedKey = null;
      _keyProblem = null;
      if (!_pastedKey) _hostKey.clear();
    });
    _checkInputsMoved();
    if (_address.text.trim().isNotEmpty && !_pastedKey) {
      _keyDebounce = Timer(const Duration(milliseconds: 500), _fetchKey);
    }
  }

  Future<void> _fetchKey() async {
    _keyDebounce?.cancel();
    if (_busy) return;
    final request = ++_keyRequest;
    final address = _address.text.trim();
    setState(() {
      _fetchingKey = true;
      _pastedKey = false;
      _keyConfirmed = false;
      _fetchedKey = null;
      _hostKey.clear();
      _keyProblem = null;
    });
    _checkInputsMoved();
    try {
      final fetched = await fetchPreparationHostKey(address, run: widget.runKeyCommand);
      if (!mounted || request != _keyRequest) return;
      setState(() {
        _fetchedKey = fetched;
        _hostKey.text = fetched.key;
      });
      _checkInputsMoved();
    } on WorkspaceRefused catch (refused) {
      if (mounted && request == _keyRequest) setState(() => _keyProblem = refused.words);
    } finally {
      if (mounted && request == _keyRequest) setState(() => _fetchingKey = false);
    }
  }

  /// Everything the shown answer was given; another of these makes it an answer about something else.
  String get _checkInputs => [_address.text.trim(), _hostKey.text.trim(), ..._choices.arguments].join('\n');

  bool get _checkPassed => widget.hostCheck == null || (_checkAnswer?.passed == true && _checkedFor == _checkInputs);

  bool _mayCheck(HostAccess? access) =>
      !_busy && !_fetchingKey && !_checking && _keyReady && access != null && _refusal(access) == null;

  /// Drops an answer about what has just changed; one that was shown is asked again, once typing rests.
  void _checkInputsMoved() {
    if (widget.hostCheck == null || !mounted || _checkInputs == _checkedFor) return;
    _checkDebounce?.cancel();
    _checkRequest++;
    final again = _checkAnswer != null || _checking || _checkAgain;
    setState(() {
      _checkAnswer = null;
      _checkedFor = null;
      _checking = false;
      _checkAgain = again;
    });
    if (again) _checkDebounce = Timer(const Duration(milliseconds: 500), _runCheck);
  }

  Future<void> _runCheck() async {
    _checkDebounce?.cancel();
    final check = widget.hostCheck;
    final access = widget.hostAccess ?? widget.hostRuns?.hostAccess;
    if (check == null || !mounted || !_mayCheck(access)) return;
    final request = ++_checkRequest;
    final identity = access!.identity();
    setState(() {
      _checking = true;
      _checkAgain = false;
      _checkAnswer = null;
      _checkedFor = _checkInputs;
    });
    final answer = identity == null
        ? const HostCheckAnswer.notAnswered('Your Machine Admin key could not be read.')
        : await check.check(
            address: _address.text.trim(),
            hostKey: _hostKey.text.trim(),
            publicKey: identity.key,
            settings: _choices,
          );
    if (!mounted || request != _checkRequest) return;
    setState(() {
      _checking = false;
      _checkAnswer = answer;
    });
    // The list stands below the fold of a long form, where nothing else says the button was answered.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_checkShown.currentContext case final shown? when mounted) unawaited(Scrollable.ensureVisible(shown));
    });
  }

  Future<void> _readAccess(HostAccess access) async {
    try {
      await access.readAgain();
      if (mounted) setState(() => _proven = true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _problem = 'Your identity and the Porelo organization could not be read. Close this dialog and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _readingAccess = false);
    }
  }

  // Only a named host's own admins may prepare it, so nothing is offered before the name.
  /// The stopped run is let go, and the form stands again with what it knew, but for the key.
  Future<void> _enterAnotherKey(HostPreparation run) async {
    final name = run.record.hostName;
    final address = run.record.givenAddress;
    await widget.hostRuns?.startOver(run);
    if (!mounted) return;
    setState(() {
      _startedOver = true;
      _started = null;
      _problem = null;
      _pastedKey = false;
      _name.text = name;
      _address.text = address;
      _hostKey.clear();
    });
    _addressChanged();
  }

  /// The machines this person can prepare now: none refused, none with a preparation of its own already.
  List<String> _choicesOf(HostAccess access) {
    final runs = widget.hostRuns;
    return [
      for (final each in access.hostsOfMine)
        if (access.unavailable(each) == null &&
            _settings.hostUp(each) == null &&
            !(runs?.of(each)?.running ?? false) &&
            !(runs?.of(each)?.waiting ?? false))
          each,
    ];
  }

  /// Why there is nothing to choose, where the words beside the button do not say it already.
  String? _whyNoChoice(HostAccess access) {
    final mine = access.hostsOfMine;
    if (access.unavailable() != null) return null;
    if (mine.isEmpty) {
      return 'You are Machine Admin of no machine the organization lists. An Organization Admin adds one under '
          'Organization, and names you its Machine Admin.';
    }
    final refused = [for (final each in mine) ?access.unavailable(each)];
    return refused.isNotEmpty
        ? refused.first
        : 'Each machine of yours has a preparation already: open it from its row under My machines.';
  }

  /// Only a machine that can be prepared is offered, so the name cannot be typed into a refusal.
  Widget _machineChoice(HostAccess? access) {
    final ready = access != null && _proven;
    final choices = ready ? _choicesOf(access) : const <String>[];
    final chosen = _name.text.trim();
    if (ready && chosen.isNotEmpty && !choices.contains(chosen)) {
      // The organization was read again and this one is no longer offered.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(_name.clear);
      });
    }
    if (ready && choices.isEmpty) {
      final why = _whyNoChoice(access);
      return why == null
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(top: Space.small),
              child: Text(why, key: const Key('preparation-no-machine')),
            );
    }
    return Padding(
      padding: const EdgeInsets.only(top: Space.small),
      // Its own state reads the first value alone, so another list or choice makes a new field.
      child: KeyedSubtree(
        key: ValueKey(<String>[...choices, '/', chosen].join(',')),
        child: DropdownButtonFormField<String>(
          key: const Key('preparation-machine-name'),
          initialValue: choices.contains(chosen) ? chosen : null,
          decoration: const InputDecoration(
            labelText: 'Machine name',
            helperText: 'A machine the organization lists, of which you are a Machine Admin.',
          ),
          items: [for (final each in choices) DropdownMenuItem(value: each, child: Text(each))],
          onChanged: _busy ? null : (value) => setState(() => _name.text = value ?? ''),
        ),
      ),
    );
  }

  /// The command to open root, where the last run stopped for want of it and this person may see it.
  String? _rootCommandAgain(HostAccess? access, HostPreparation? run) {
    if (access == null || _readingAccess || !_proven) return null;
    if (!(run?.problem ?? _problem ?? '').contains(rootStillClosed)) return null;
    try {
      return access.bootstrapCommand();
    } on HostAccessRefused {
      return null;
    }
  }

  /// What *Prepare the machine* waits for now, in words that stay beside it; null once it can be pressed.
  String? _waitsFor(HostAccess? access) {
    if (access == null) return 'This computer cannot prepare a machine from here.';
    if (_busy) return 'Checking that you may prepare it…';
    if (_refusal(access) case final reason?) {
      return reason == _problem ? 'It stopped: the words above say why.' : reason;
    }
    if (_fetchingKey) return 'Fetching the SSH host key, up to a few seconds.';
    if (_hostKey.text.trim().isEmpty) return 'Waiting for the machine\'s SSH host key: fetch it, or paste it above.';
    if (!_keyReady) return 'Waiting for you: tick "I compared this fingerprint" above.';
    if (widget.hostCheck != null && !_checkPassed) {
      if (_checking || _checkAgain) return 'Checking the machine. This only reads, and changes nothing on it.';
      return switch (_checkAnswer) {
        null => 'Check the machine first. This only reads, and changes nothing on it.',
        final answer when !answer.answered => 'The check gave no answer, so nothing is known of this machine yet.',
        _ => 'Preparing is offered once the check passes.',
      };
    }
    return null;
  }

  String? _refusal(HostAccess access) {
    if (_readingAccess) return 'Reading your identity and the Porelo organization…';
    if (!_proven) return _problem ?? 'Your identity and the Porelo organization have not been read.';
    final name = _name.text.trim();
    if (name.isEmpty) {
      return access.unavailable() ??
          (_choicesOf(access).isEmpty
              ? 'There is no machine to choose.'
              : 'Choose the machine first: only its Machine Admins may prepare it.');
    }
    return access.unavailable(name);
  }

  Future<void> _prepare() async {
    if (_busy || !_proven || !_keyReady || _fetchingKey || !_checkPassed) return;
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      final name = _name.text.trim();
      final runs = widget.hostRuns;
      if (runs == null) throw StateError('The machine preparation owner is unavailable.');
      final access = runs.hostAccess;
      if (access == null) throw const HostAccessRefused('The verified Machine Admins are unavailable.');
      // Read anew here: nothing is rented for a key revoked since the dialog opened, nor for a pin that cannot hold.
      final machineFile = await access.machineFile(name);
      if (!mounted) return;
      // The key compared may be an installer's that has since gone: this catches a change, not a false answer.
      if (_fetchedKey case final compared?) {
        final PreparationHostKey now;
        try {
          now = await fetchPreparationHostKey(_address.text.trim(), run: widget.runKeyCommand);
        } on WorkspaceRefused {
          // Not answering now says nothing of the key; the login holds to the one filed.
          return await _prepareWith(access, runs, name, machineFile);
        }
        if (!mounted) return;
        if (now.key != compared.key) {
          setState(() {
            _fetchedKey = now;
            _hostKey.text = now.key;
            _keyConfirmed = false;
            _problem =
                'The machine\'s SSH host key changed since it was fetched, usually because an install was still '
                'running. Nothing was started. Compare the new one below.';
          });
          _checkInputsMoved();
          return;
        }
      }
      await _prepareWith(access, runs, name, machineFile);
    } on HostAccessRefused catch (refused) {
      if (mounted) setState(() => _problem = refused.words);
    } on StateError catch (error) {
      if (mounted) setState(() => _problem = error.message.toString());
    } on Exception catch (error) {
      if (mounted) setState(() => _problem = error is FormatException ? error.message : error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _prepareWith(HostAccess access, HostRuns runs, String name, String machineFile) async {
    // Read anew: a choice may have changed while the card was read, and then the answer is of another request.
    if (!_checkPassed) throw const FormatException('A choice changed, so the check runs again. Nothing was started.');
    final record = HostUpRecord.fromStored(
      HostUpRecord(
        hostName: name,
        host: name,
        givenAddress: _address.text.trim(),
        givenHostKey: _hostKey.text.trim(),
        preparationSettings: _choices,
        machineFile: machineFile,
        publicKey: access.identity()!.key,
      ).stored,
    );
    if (record == null || record.givenAddress.isEmpty) {
      throw const FormatException('Choose a machine name, a server address and SSH host key.');
    }
    final existing = runs.of(name);
    if (_settings.hostUp(name) != null || existing != null && (existing.running || existing.waiting)) {
      throw const FormatException(
        'This machine name already has saved preparation or an active run. Open it to continue.',
      );
    }
    final session = HostSession(executable: poreloHost(), arguments: hostArguments(record, name), start: widget.start);
    _started = runs.start(project: name, record: record, session: session);
    setState(() {});
    await _started!.finished;
    if (mounted) setState(() => _problem = _started!.problem);
  }

  Future<void> _readHolders() async {
    final record = _record;
    if (record == null || _checkingMemberships) return;
    final session = HostSession(
      executable: poreloHost(),
      arguments: record.giveBackArguments(widget.project),
      start: widget.start,
    );
    setState(() {
      _holders = null;
      _membershipProblem = null;
      _checkingMemberships = true;
      _membershipSession?.dispose();
      _membershipSession = session;
    });
    try {
      final holders = await session.readMemberships();
      if (mounted) setState(() => _holders = holders);
    } catch (error) {
      final reason = switch (error) {
        StateError() => error.message,
        FormatException() => error.message,
        _ => error.toString(),
      };
      // Nothing is purged then, and the play's own check still refuses while anyone holds a membership: a server
      // whose setup stopped early has nobody to read and still goes back as before.
      if (mounted) {
        setState(() {
          _holders = const [];
          _membershipProblem = 'The membership holders could not be read: $reason';
        });
      }
    } finally {
      if (mounted) setState(() => _checkingMemberships = false);
    }
  }

  /// The project states that say nothing of unpushed work; any other, a later host's word too, cannot say.
  static const _knownProjectStates = {'carried', 'pending', 'waiting-for-token', 'refused', 'held'};

  Future<void> _readCentral() async {
    if (_checkingCentral) return;
    final host = _record?.hostName.isNotEmpty == true ? _record!.hostName : widget.project;
    // The last answer stands while the host is asked again: a stalling host must not hide the way to force it.
    setState(() => _checkingCentral = true);
    try {
      final read = widget.readHostProgress;
      if (read == null) throw const OrganizationRefused('The machine is not connected.');
      final progress = await read(host).timeout(const Duration(seconds: 30));
      if (!mounted) return;
      setState(() {
        _centralBlockers = [
          if (!progress.hasRepositoryStatus) '$host: cannot say: the machine did not report a complete repository list',
          if (progress.waitsForToken) '$host: cannot say: the machine is waiting for its first token',
          for (final project in progress.projects)
            if (project.state == 'held')
              '${project.project}: holds commits not yet pushed${project.why == null ? '' : ' (${project.why})'}'
            else if (!_knownProjectStates.contains(project.state))
              '${project.project}: cannot say: the machine says "${project.state}"',
          for (final project in progress.projects)
            for (final row in project.repositories)
              if (row.state == 'taken' && (row.central ?? const HostRepositoryCentral()).blocksGiveBack)
                '${project.project}/${row.repository}: ${(row.central ?? const HostRepositoryCentral()).words}',
        ];
      });
    } catch (error) {
      final why = switch (error) {
        OrganizationRefused() => error.words,
        TimeoutException() => 'The machine did not answer within 30 seconds.',
        _ => 'The machine could not be asked: $error',
      };
      if (mounted) setState(() => _centralBlockers = ['$host: cannot say: $why']);
    } finally {
      if (mounted) setState(() => _checkingCentral = false);
    }
  }

  Future<void> _giveBack({
    bool anyway = false,
    bool centralLossConfirmed = false,
    List<HostMembership>? holders,
  }) async {
    if (_busy || _givenBack || _record == null) return;
    if (!_centralReady && !(anyway && centralLossConfirmed && _centralBlockers?.isNotEmpty == true)) return;
    if (!anyway && (holders == null || !identical(holders, _holders) || _checkingMemberships)) return;
    if (widget.hostRuns?.of(widget.project)?.running == true) return;
    final record = _record!;
    final session = HostSession(
      executable: poreloHost(),
      arguments: record.giveBackArguments(widget.project),
      start: widget.start,
    );
    setState(() {
      _busy = true;
      _problem = null;
      _notesBefore = {..._notesBefore, ...?_down?.notes};
      _down?.dispose();
      _down = session;
    });
    var readAgain = false;
    var confirmed = false;
    try {
      await session.down(
        giveBackAnyway: anyway,
        purge: anyway ? const [] : [for (final holder in holders!) holder.login],
      );
      if (!hostGivenBack(session)) {
        throw StateError(
          record.isRental ? 'The rental return was not confirmed.' : 'Taking Porelo off was not confirmed.',
        );
      }
      confirmed = true;
      _returnedRental = record.isRental;
      final owner = widget.hostRuns;
      if (owner != null) {
        _problem = await owner.confirmDown(widget.project, session);
      } else {
        _problem = widget.hostAccess?.cardLeftBehind(widget.project);
        await _settings.forgetHostUp(widget.project);
      }
      // The question promised it: a machine confirmed down leaves the organization's list too. A refusal is said, and
      // the row keeps its own *Remove the machine…*.
      if (widget.removeFromOrganization case final remove?) {
        String? refused;
        try {
          // Close waits on this: a removal that does not answer in time is said, and goes on by itself.
          refused = await remove(record.hostName).timeout(_removalPatience);
        } on TimeoutException {
          refused = 'it did not answer within two minutes, and may still go through: look at the list';
        } on Exception catch (error) {
          refused = '$error';
        }
        if (refused == null) {
          // What was said of the organization still naming the machine no longer holds.
          _problem = null;
          widget.hostRuns?.forgetLeftBehind(widget.project);
        } else {
          _problem =
              '${record.hostName} stays on the organization\'s list: $refused. Remove it there with *Remove the '
              'machine…* on its row.';
        }
      }
      for (final machine
          in widget.machines.all.where((m) => m.kind == 'host' && m.hostProject == widget.project).toList()) {
        await widget.machines.forget(machine);
      }
      _givenBack = true;
    } catch (_) {
      _problem = confirmed
          ? '${_doneWords(rental: record.isRental)} This window could not forget it, and shows it until it can.'
          : session.protocolText.contains('Permission denied')
          ? notTheAdminsKey(record.hostName)
          : record.isRental
          ? 'The rental return was not confirmed. It stays billed, and its recovery data were kept.'
          : 'Taking Porelo off was not confirmed. The machine and recovery data were kept.';
      readAgain = !confirmed;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    // Reads must not hold Close while a host stalls; loss still needs its own decision.
    if (readAgain && mounted) {
      unawaited(_readHolders());
      unawaited(_readCentral());
    }
  }

  /// How long a confirmed take-down waits on the organization's removal before Close is free again.
  static const _removalPatience = Duration(minutes: 2);

  /// What a confirmed take-down has done, whatever this window then manages to keep of it.
  static String _doneWords({required bool rental}) => rental
      ? 'The provider confirmed the rental return. Billing has ended.'
      : 'Porelo was taken off. The machine itself stays yours.';

  /// A run's steps, kept at their newest unless the person has scrolled up to read.
  Widget _following(String steps) {
    final at = _scroll.hasClients ? _scroll.position : null;
    if (at == null || !at.hasContentDimensions || at.pixels >= at.maxScrollExtent - 48) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    }
    return SelectableText(steps);
  }

  @override
  void dispose() {
    _keyDebounce?.cancel();
    _keyRequest++;
    _checkDebounce?.cancel();
    _checkRequest++;
    _down?.dispose();
    _membershipSession?.stopReading();
    _membershipSession?.dispose();
    for (final field in [_name, _address, _hostKey]) {
      field.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  /// A refusal can stand below the dialog's fold, where nothing else says the button was answered.
  void _bringProblemIntoView() {
    if (_problem == _problemBroughtIntoView) return;
    _problemBroughtIntoView = _problem;
    if (_problem == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_problemShown.currentContext case final shown? when mounted) {
        unawaited(Scrollable.ensureVisible(shown));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final run = _startedOver ? _started : widget.existingRun ?? _started;
    final record = _record ?? (run == null ? null : _settings.hostUp(run.project)) ?? run?.record;
    final access = widget.hostAccess ?? widget.hostRuns?.hostAccess;
    final holders = _holders;
    final rental = _givenBack ? _returnedRental : record != null && record.isRental;
    _bringProblemIntoView();
    return AlertDialog(
      // Anchored above, so a form or a list growing below moves nothing a person is reading or about to click.
      alignment: Alignment.topCenter,
      title: Text(
        widget.takeDownOnly
            ? rental
                  ? 'Return this rental…'
                  : 'Take Porelo off this machine…'
            : run?.name ?? 'Prepare a machine',
      ),
      content: SizedBox(
        width: Sizes.dialog,
        child: SingleChildScrollView(
          controller: _scroll,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_busy && run == null && !widget.takeDownOnly)
                Text('Checking permission to prepare machine ${_name.text.trim()}…'),
              if (widget.takeDownOnly && !_givenBack)
                if (access?.projectsOn(record?.hostName.isNotEmpty == true ? record!.hostName : widget.project)
                    case final projects? when projects.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.small),
                    child: Text(
                      'Still on this machine: ${projects.join(', ')}. Only what has reached the central forge is safe: work '
                      'only on the machine’s own forge goes with it.',
                      key: const Key('host-projects-left'),
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
              if (widget.takeDownOnly && !_givenBack)
                Text(
                  rental
                      ? 'Delete the accounts named below and everything they hold here, and remove this machine from the organization’s list? The provider then removes the machine, ending its billing once the provider confirms.'
                      : 'Delete the accounts named below and everything they hold here, and remove this machine from the organization’s list? The machine itself stays yours. End any contract with its provider yourself.',
                ),
              if (!widget.takeDownOnly && run == null) ...[
                if (access == null) const Text('Verified Machine Admin identity and the organization are unavailable.'),
                _machineChoice(access),
                for (final field in [
                  (
                    _address,
                    'Server address',
                    'The machine name or IP address this computer reaches the existing server at.',
                  ),
                  (_hostKey, 'SSH host key', 'The server’s ssh-ed25519 public key, checked separately.'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(top: Space.small),
                    child: TextField(
                      controller: field.$1,
                      readOnly: _busy,
                      decoration: InputDecoration(labelText: field.$2, helperText: field.$3),
                      // The host name decides whose admins may prepare it, so its refusal follows each change.
                      onChanged: (_) {
                        if (field.$1 == _address) {
                          _addressChanged();
                        } else {
                          setState(() {
                            if (field.$1 == _hostKey) {
                              _keyRequest++;
                              _keyDebounce?.cancel();
                              _fetchingKey = false;
                              _pastedKey = _hostKey.text.trim().isNotEmpty;
                              _fetchedKey = null;
                              _keyConfirmed = false;
                              _keyProblem = null;
                            }
                          });
                          _checkInputsMoved();
                        }
                      },
                    ),
                  ),
                TextButton(
                  onPressed: _busy || _fetchingKey || _address.text.trim().isEmpty ? null : _fetchKey,
                  child: const Text('Fetch SSH host key'),
                ),
                if (_fetchingKey) const Text('Fetching the SSH host key…'),
                if (_keyProblem != null) Text(_keyProblem!),
                if (_fetchedKey case final fetched?) ...[
                  SelectableText(fetched.fingerprint),
                  const Text(
                    'Wait until your provider says the server is ready and its install has finished: a key fetched '
                    'before that is the installer\'s. Then run this on the server itself and compare what it prints '
                    'with the fingerprint above.',
                  ),
                  const SelectableText(
                    'ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub',
                    key: Key('preparation-compare-command'),
                  ),
                  CheckboxListTile(
                    key: const Key('preparation-host-key-confirmed'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('I compared this fingerprint'),
                    value: _keyConfirmed,
                    onChanged: _busy
                        ? null
                        : (value) {
                            setState(() => _keyConfirmed = value == true);
                            _checkInputsMoved();
                          },
                  ),
                ],
                // Below the fields, so that what it says as the name is typed moves none of them.
              ],
              // A host set up already: what it was set to, which this dialog changes no more.
              if (record?.preparedHost case final _?) Text(key: const Key('host-choices'), _setTo(record!)),
              if (!widget.takeDownOnly && run == null && record?.preparedHost == null) ...[
                SwitchListTile(
                  key: const Key('host-forge'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('This host has a forge of its own'),
                  subtitle: const Text(
                    'On: builds run here, and take memory and CPUs from the tasks. Off: a central forge alone, with '
                    'less to run on the machine.',
                  ),
                  value: _choices.forge,
                  onChanged: _busy
                      ? null
                      : (value) => _choose(_choices.withPlainChoices(forge: value, kvm: value && _choices.kvm)),
                ),
                if (_choices.forge)
                  SwitchListTile(
                    key: const Key('host-check-vms'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('This host runs VMs in its jobs'),
                    subtitle: const Text(
                      'On installs KVM and libvirt, needs a CPU with virtualization, and is for a job that makes a VM; '
                      'a job in a container needs none of it.',
                    ),
                    value: _choices.kvm,
                    onChanged: _busy ? null : (value) => _choose(_choices.withPlainChoices(forge: true, kvm: value)),
                  ),
                HostPreparationSettingsForm(value: _choices, onChanged: (value) => _choose(value)),
                if (access != null && _proven && _refusal(access) == null) ...[
                  const Text(
                    'Before setup, on the server, not on this computer: log in there with the first login your '
                    'provider gave you, such as ubuntu, and run this line. It replaces root’s authorized keys with '
                    'your Machine Admin card key, and from then on Porelo logs in as root.',
                  ),
                  CommandToCopy(command: access.bootstrapCommand(), textKey: const Key('host-bootstrap-command')),
                ],
              ],
              if (!widget.takeDownOnly && run == null) ...[
                if (_checking) const Text('Checking the machine…', key: Key('host-check-running')),
                if (_checkAnswer case final answer?) HostCheckList(key: _checkShown, answer: answer),
              ],
              // The run stopped on the very command it asked for: it is shown again, above the words that say so.
              if (_rootCommandAgain(access, run) case final command?) ...[
                const Text('Run it on the server, logged in with your provider’s first login, not on this computer:'),
                CommandToCopy(command: command, textKey: const Key('preparation-root-command')),
                if (_problem == null && run?.problem != null) Text(run!.problem!),
              ],
              if (_problem != null) Text(_problem!, key: _problemShown),
              // Reopened from its row: what stopped it stands above the protocol, with ssh's own line.
              if (_problem == null && run != null && (widget.hostRuns?.mayStartOver(run) ?? false))
                Text(run.problem!, key: const Key('preparation-key-refused')),
              if (widget.takeDownOnly && !_givenBack) ...[
                if (_checkingCentral) const Text('Checking the repositories against central…'),
                if (_centralBlockers case final blockers? when blockers.isNotEmpty) ...[
                  const Text('This machine cannot be given back safely:'),
                  for (final blocker in blockers) Text(blocker),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: Space.small),
                    child: Text(
                      'Giving it back anyway means work that has not reached the central forge will be lost, '
                      'including work in the repositories named above. This cannot be undone.',
                    ),
                  ),
                ],
                if (_checkingMemberships) const Text('Reading membership holders…'),
                if (_membershipProblem != null) Text(_membershipProblem!),
                if (holders != null && holders.isNotEmpty) ...[
                  for (final holder in holders)
                    Text(
                      '${holder.login}: ${[if (holder.hostAdmin) 'Machine Admin', for (final project in holder.projects) '${project.project} (${project.role})'].join(', ')}',
                    ),
                  const Text(
                    'The accounts named above and everything they hold here are permanently deleted. This cannot be undone.',
                  ),
                ],
              ],
              if (_problem != null && !_givenBack && widget.takeDownOnly && _centralBlockers?.isNotEmpty != true)
                const Text(
                  'Going on without a backup deletes everything still in these accounts. Confirm only when their contents are no longer needed.',
                ),
              if (!widget.takeDownOnly)
                if (record?.preparedHost != null) const PreparedHostPanel(),
              if (_givenBack) Text(_doneWords(rental: rental)),
              if (run != null)
                ListenableBuilder(
                  listenable: widget.hostRuns ?? run.session,
                  builder: (_, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (run.running)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Space.small),
                          child: Text(
                            'Preparing machine ${run.name}. This can take minutes. Preparation continues if you close '
                            'this dialog; its machine row opens the protocol again.',
                          ),
                        ),
                      _following(run.session.protocolText),
                    ],
                  ),
                ),
              if (_down case final session? when !_returnedRental)
                ListenableBuilder(
                  listenable: session,
                  builder: (_, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final note in {..._notesBefore, ...session.notes})
                        Padding(
                          padding: const EdgeInsets.only(bottom: Space.small),
                          child: SelectableText('The machine says: $note'),
                        ),
                    ],
                  ),
                ),
              if (_down case final session?)
                ListenableBuilder(listenable: session, builder: (_, _) => _following(session.protocolText)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy && (widget.takeDownOnly || run == null) ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (!widget.takeDownOnly && run == null)
          if (_waitsFor(access) case final waits?)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Sizes.dialogWords),
              child: Text(waits, key: const Key('preparation-waits')),
            ),
        if (!widget.takeDownOnly && run == null && !_checkPassed)
          FilledButton(
            key: const Key('host-check-run'),
            onPressed: _mayCheck(access) ? _runCheck : null,
            child: const Text('Check this machine'),
          )
        else if (!widget.takeDownOnly && run == null)
          FilledButton(
            onPressed: _busy || _fetchingKey || !_keyReady || access == null || _refusal(access) != null
                ? null
                : _prepare,
            child: const Text('Prepare the machine'),
          ),
        if (!widget.takeDownOnly && run != null && (widget.hostRuns?.mayStartOver(run) ?? false))
          FilledButton(
            key: const Key('preparation-another-key'),
            onPressed: () => unawaited(_enterAnotherKey(run)),
            child: const Text('Enter the key again'),
          )
        else if (!widget.takeDownOnly && run != null && !run.ready && !run.running)
          FilledButton(
            onPressed: () async {
              setState(() => _problem = null);
              await widget.hostRuns?.resume(run);
              if (mounted) setState(() => _problem = run.problem);
            },
            child: const Text('Prepare the machine again'),
          ),
        if (widget.takeDownOnly && !_givenBack)
          FilledButton(
            key: const Key('host-confirm-down'),
            onPressed:
                _busy ||
                    !_centralReady ||
                    _checkingCentral ||
                    _checkingMemberships ||
                    holders == null ||
                    record == null ||
                    widget.hostRuns?.of(widget.project)?.running == true
                ? null
                : () => _giveBack(holders: holders),
            child: Text(
              holders?.isNotEmpty == true
                  ? rental
                        ? 'Delete these accounts and return it'
                        : 'Delete these accounts and take Porelo off'
                  : rental
                  ? 'Return it'
                  : 'Take Porelo off',
            ),
          ),
        if (widget.takeDownOnly && !_givenBack && _centralBlockers?.isNotEmpty == true)
          OutlinedButton(
            key: const Key('host-give-back-anyway'),
            onPressed: _busy ? null : () => _giveBack(anyway: true, centralLossConfirmed: true),
            child: const Text('Give it back anyway'),
          ),
        if (widget.takeDownOnly && !_givenBack && _problem != null && _centralBlockers?.isNotEmpty != true)
          OutlinedButton(
            key: const Key('host-force-down'),
            onPressed: _busy || !_centralReady ? null : () => _giveBack(anyway: true),
            child: const Text('Go on without a backup'),
          ),
      ],
    );
  }
}

/// Says that the checked completion reached the organization.
class PreparedHostPanel extends StatelessWidget {
  /// Shown once the host's card holds its real address, host key and ports.
  const PreparedHostPanel({super.key});

  @override
  Widget build(BuildContext context) => const Text(
    "The machine is ready, and its address, SSH host key and ports stand on its card in the organization.",
  );
}
