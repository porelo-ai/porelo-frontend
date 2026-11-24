import 'dart:async';

import 'package:flutter/material.dart';
import 'package:porelo_host/porelo_host.dart' show HostMembership, rootStillClosed;

import '../app/host_runs.dart';
import '../app/host_access.dart';
import '../app/host_session.dart';
import '../app/machines.dart';
import '../app/host_progress.dart';
import '../app/organization_source.dart' show OrganizationRefused;
import '../app/session.dart';
import '../app/settings.dart';
import 'command_to_copy.dart';
import 'following_output.dart';
import 'tokens.dart';
import 'dialog_scroll.dart';
import 'machine_tree.dart' show centralWords;
import '../wire/limit_factors.dart';

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

/// Opens the retained public setup protocol; [onEnterKeyAgain] gives a run refused for its key to the setup wizard.
Future<void> openHostRunDialog(
  BuildContext context, {
  required HostPreparation run,
  required HostRuns hostRuns,
  required Machines machines,
  Settings? settings,
  OpenTerminal? openTerminal,
  void Function(HostPreparation run)? onEnterKeyAgain,
}) => showDialog<void>(
  context: context,
  builder: (_) => HostDialog(
    project: run.project,
    machines: machines,
    settings: settings,
    hostRuns: hostRuns,
    existingRun: run,
    onEnterKeyAgain: onEnterKeyAgain,
  ),
);

/// A preparation's protocol, opened from its row, or a machine's explicit give-back.
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
    this.takeDownOnly = false,
    this.removeFromOrganization,
    this.fromTheCard,
    this.readHostProgress,
    this.onEnterKeyAgain,
    super.key,
  }) : assert(takeDownOnly || existingRun != null, 'a protocol is of a run');

  /// Opens the setup wizard at the key for a run refused for its key; this dialog closes first. Null offers nothing.
  final void Function(HostPreparation run)? onEnterKeyAgain;

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

  /// Whether the dialog confirms give-back.
  final bool takeDownOnly;

  /// Removes the machine from the organization's list once it is confirmed down; answers a refusal's words, or null.
  final Future<String?> Function(String host)? removeFromOrganization;

  /// What to take down with on a computer that kept nothing from setting it up.
  final HostUpRecord? fromTheCard;

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
  bool _busy = false;
  bool _givenBack = false;
  bool _returnedRental = false;
  String? _problem;
  final _problemShown = GlobalKey();
  String? _problemBroughtIntoView;
  Settings get _settings => widget.settings ?? widget.machines.settings;
  HostUpRecord? get _record => _settings.hostUp(widget.project) ?? widget.fromTheCard;

  String _setTo(HostUpRecord record) {
    final forge = record.forge && record.preparationSettings.forge;
    return '${forge ? 'It has a forge of its own' : 'It has no forge of its own'}'
        '${forge && record.preparationSettings.kvm ? ', and runs VMs in its jobs.' : ', and runs no VMs in its jobs.'}';
  }

  @override
  void initState() {
    super.initState();
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

  /// The repositories the daemon of the machine called [host] says stand otherwise than at central, as it last listed
  /// them: ahead, moved on, cannot say (but for a repository with no central forge), a later word, or commits ahead.
  /// A repository it says it does not carry, or of whose central it says nothing, adds nothing here.
  List<({String project, String repository, String words})> _daemonCentralBlockers(String host) => [
    for (final machine in widget.machines.all)
      if (machine.hostCard?.name == host)
        for (final project in widget.machines.watching(machine)?.projects ?? const <Never>[])
          for (final repository in project.project.repositoryStates)
            if (repository.carriedHere != false &&
                repository.central != null &&
                ((repository.ahead ?? 0) > 0 ||
                    HostRepositoryCentral(state: repository.central!, why: repository.centralWhy).blocksGiveBack))
              (
                project: project.name,
                repository: repository.name,
                words: centralWords(repository) ?? 'cannot say: the machine did not report its central state',
              ),
  ];

  Future<void> _readCentral() async {
    if (_checkingCentral) return;
    final host = _record?.hostName.isNotEmpty == true ? _record!.hostName : widget.project;
    // The last answer stands while the host is asked again: a stalling host must not hide the way to force it.
    setState(() => _checkingCentral = true);
    try {
      final read = widget.readHostProgress;
      if (read == null) throw const OrganizationRefused('The machine is not connected.');
      final progress = await read(host).timeout(serviceWait(const Duration(seconds: 30)));
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
          // What the machine's own Porelo last said blocks too: one of the two may be older, and up to date from one
          // never lets the other's loss through.
          for (final (:project, :repository, :words) in _daemonCentralBlockers(host))
            if (!progress.projects.any(
              (each) =>
                  each.project == project &&
                  each.repositories.any(
                    (row) =>
                        row.repository == repository &&
                        row.state == 'taken' &&
                        (row.central ?? const HostRepositoryCentral()).blocksGiveBack,
                  ),
            ))
              '$project/$repository: $words',
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

  /// Today on the machine's calendar, as its purge day is written.
  static String _today() => DateTime.now().toUtc().toIso8601String().substring(0, 10);

  /// The holders the machine purges: the take-down offers only those.
  static List<HostMembership> _purged(List<HostMembership> holders) => [
    for (final holder in holders)
      if (holder.whyNotPurged(_today()) == null) holder,
  ];

  /// What [holder] holds here, in words.
  static String _holds(HostMembership holder) => [
    if (holder.hostAdmin) 'Machine Admin',
    for (final project in holder.projects) '${project.project} (${project.role})',
    if (!holder.hostAdmin && holder.projects.isEmpty) holder.state,
  ].join(', ');

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
        purge: anyway ? const [] : [for (final holder in _purged(holders!)) holder.login],
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
          refused = await remove(record.hostName).timeout(serviceWait(_removalPatience));
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

  /// How long a confirmed take-down waits on the organization's removal before Close is free; the removal goes on.
  static const _removalPatience = Duration(minutes: 2);

  /// What a confirmed take-down has done, whatever this window then manages to keep of it.
  static String _doneWords({required bool rental}) => rental
      ? 'The provider confirmed the rental return. Billing has ended.'
      : 'Porelo was taken off. The machine itself stays yours.';

  @override
  void dispose() {
    _down?.dispose();
    _membershipSession?.stopReading();
    _membershipSession?.dispose();
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
    final run = widget.existingRun;
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
            : run!.name,
      ),
      content: SizedBox(
        width: Sizes.dialog,
        // A long list of holders or blockers scrolls, with a sign that more stands below, in a short window.
        child: DialogScroll(
          controller: _scroll,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              // A host set up already: what it was set to, which this dialog changes no more.
              if (record?.preparedHost case final _?) Text(key: const Key('host-choices'), _setTo(record!)),
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
                      '${holder.login}: ${_holds(holder)}'
                      '${switch (holder.whyNotPurged(_today())) {
                        final why? => '; not offered: the machine purges only an account locked, listed in no project '
                            'and past its purge day, and $why.',
                        null => '',
                      }}',
                    ),
                  if (_purged(holders).isNotEmpty)
                    Text(
                      '${_purged(holders).map((holder) => holder.login).join(', ')} and everything '
                      '${_purged(holders).length == 1 ? 'it holds' : 'they hold'} here are permanently deleted. '
                      'This cannot be undone.',
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
                      FollowingOutput(text: run.session.protocolText, waitingForFirstLine: run.waitsForFirstLine),
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
                ListenableBuilder(
                  listenable: session,
                  builder: (_, _) => FollowingOutput(text: session.protocolText),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy && widget.takeDownOnly ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (!widget.takeDownOnly && run != null && (widget.hostRuns?.mayStartOver(run) ?? false))
          FilledButton(
            key: const Key('preparation-another-key'),
            onPressed: widget.onEnterKeyAgain == null
                ? null
                : () {
                    // The wizard takes it from here; this run stays as it is until a new one starts.
                    Navigator.pop(context);
                    widget.onEnterKeyAgain!(run);
                  },
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
              holders != null && _purged(holders).isNotEmpty
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
