import 'dart:async';

import 'package:flutter/material.dart';
import 'package:porelo_host/porelo_host.dart' show HostMembership, HostPreparationSettings;

import '../app/host_runs.dart';
import '../app/host_access.dart';
import '../app/host_session.dart';
import '../app/machines.dart';
import '../app/session.dart';
import '../app/settings.dart';
import 'tokens.dart';
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
  OpenTerminal? openTerminal,
  bool? linux,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => HostDialog(
    project: project,
    machines: machines,
    settings: settings,
    hostRuns: hostRuns,
    hostAccess: hostAccess,
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
}) => showDialog<void>(
  context: context,
  builder: (_) => HostDialog(project: '', machines: machines, settings: settings, hostRuns: hostRuns),
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
    this.takeDownOnly = false,
    super.key,
  });

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

  @override
  State<HostDialog> createState() => _HostDialogState();
}

class _HostDialogState extends State<HostDialog> {
  HostSession? _down;
  HostSession? _membershipSession;
  List<HostMembership>? _holders;
  bool _checkingMemberships = false;
  String? _membershipProblem;
  final _scroll = ScrollController();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _hostKey = TextEditingController();
  HostPreparation? _started;
  bool _busy = false;
  bool _givenBack = false;
  bool _returnedRental = false;
  String? _problem;
  final _problemShown = GlobalKey();
  String? _problemBroughtIntoView;
  HostPreparationSettings _choices = const HostPreparationSettings();
  Settings get _settings => widget.settings ?? widget.machines.settings;
  HostUpRecord? get _record => _settings.hostUp(widget.project);

  @override
  void initState() {
    super.initState();
    _choices = _record?.preparationSettings ?? widget.existingRun?.record.preparationSettings ?? _choices;
    if (widget.takeDownOnly) {
      unawaited(_readHolders());
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
          _problem = 'Your identity and the organization could not be read. Close this dialog and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _readingAccess = false);
    }
  }

  // Only a named host's own admins may prepare it, so nothing is offered before the name.
  String? _refusal(HostAccess access) {
    if (_readingAccess) return 'Reading your identity and the organization…';
    if (!_proven) return _problem ?? 'Your identity and the organization have not been read.';
    final name = _name.text.trim();
    return name.isEmpty ? 'Name the machine first: only its Machine Admins may prepare it.' : access.unavailable(name);
  }

  Future<void> _prepare() async {
    if (_busy || !_proven) return;
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
      final record = HostUpRecord.fromStored(
        HostUpRecord(
          hostName: name,
          host: name,
          givenAddress: _address.text.trim(),
          givenHostKey: _hostKey.text.trim(),
          preparationSettings: _choices,
          machineFile: machineFile,
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
      final session = HostSession(
        executable: poreloHost(),
        arguments: hostArguments(record, name),
        start: widget.start,
      );
      _started = runs.start(project: name, record: record, session: session);
      setState(() {});
      await _started!.finished;
      if (mounted) setState(() => _problem = _started!.problem);
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

  Future<void> _giveBack({bool anyway = false, List<HostMembership>? holders}) async {
    if (_busy || _givenBack || _record == null) return;
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
      _down?.dispose();
      _down = session;
    });
    var readAgain = false;
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
      final owner = widget.hostRuns;
      if (owner != null) {
        _problem = await owner.confirmDown(widget.project, session);
      } else {
        _problem = widget.hostAccess?.cardLeftBehind(widget.project);
        await _settings.forgetHostUp(widget.project);
      }
      for (final machine
          in widget.machines.all.where((m) => m.kind == 'host' && m.hostProject == widget.project).toList()) {
        await widget.machines.forget(machine);
      }
      _returnedRental = record.isRental;
      _givenBack = true;
    } catch (_) {
      _problem = record.isRental
          ? 'The rental return was not confirmed. It stays billed, and its recovery data were kept.'
          : 'Taking Porelo off was not confirmed. The machine and recovery data were kept.';
      readAgain = !anyway;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    // Not under busy: a host that stalls here must leave Close and the give-back without a backup open.
    if (readAgain && mounted) unawaited(_readHolders());
  }

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
    final run = widget.existingRun ?? _started;
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
              if (_readingAccess && run == null && !widget.takeDownOnly)
                const Padding(
                  padding: EdgeInsets.only(bottom: Space.small),
                  child: Text('Reading your identity and the organization…'),
                ),
              if (_busy && run == null && !widget.takeDownOnly)
                Text('Checking permission to prepare machine ${_name.text.trim()}…'),
              if (widget.takeDownOnly && !_givenBack)
                Text(
                  rental
                      ? 'Delete the accounts named below and everything they hold here, and remove this machine from the organization’s list? The provider then removes the machine, ending its billing once the provider confirms.'
                      : 'Delete the accounts named below and everything they hold here, and remove this machine from the organization’s list? The machine itself stays yours. End any contract with its provider yourself.',
                ),
              if (!widget.takeDownOnly && run == null) ...[
                if (access == null) const Text('Verified Machine Admin identity and the organization are unavailable.'),
                for (final field in [
                  (_name, 'Machine name', 'One lower-case server name, such as orchard.'),
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
                      decoration: InputDecoration(labelText: field.$2, helperText: field.$3),
                      // The host name decides whose admins may prepare it, so its refusal follows each change.
                      onChanged: field.$1 == _name ? (_) => setState(() {}) : null,
                    ),
                  ),
                // Below the fields, so that what it says as the name is typed moves none of them.
                if (access != null && !_readingAccess)
                  if (_refusal(access) case final reason? when reason != _problem)
                    Padding(
                      padding: const EdgeInsets.only(top: Space.small),
                      child: Text(reason),
                    ),
              ],
              if (!widget.takeDownOnly && run == null && record?.preparedHost == null) ...[
                HostPreparationSettingsForm(
                  value: _choices,
                  onChanged: (value) async {
                    setState(() => _choices = value);
                    if (_record case final saved?) {
                      try {
                        await _settings.rememberHostUp(widget.project, saved.withPreparationSettings(value));
                      } on Exception {
                        if (mounted) setState(() => _problem = 'The preparation settings could not be saved.');
                      }
                    }
                  },
                ),
                if (access != null && _proven && _refusal(access) == null) ...[
                  const Text(
                    'Before setup, run this in a separate terminal on the server. It replaces root’s authorized keys with your Machine Admin card key.',
                  ),
                  SelectableText(access.bootstrapCommand()),
                ],
              ],
              if (_problem != null) Text(_problem!, key: _problemShown),
              if (widget.takeDownOnly && !_givenBack) ...[
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
              if (_problem != null && !_givenBack && widget.takeDownOnly)
                const Text(
                  'Going on without a backup deletes everything still in these accounts. Confirm only when their contents are no longer needed.',
                ),
              if (!widget.takeDownOnly)
                if (record?.preparedHost != null) const PreparedHostPanel(),
              if (_givenBack)
                Text(
                  rental
                      ? 'The provider confirmed the rental return. Billing has ended.'
                      : 'Porelo was taken off. The machine itself stays yours.',
                ),
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
          FilledButton(
            onPressed: _busy || access == null || _refusal(access) != null ? null : _prepare,
            child: const Text('Prepare the machine'),
          ),
        if (!widget.takeDownOnly && run != null && !run.ready && !run.running)
          FilledButton(
            onPressed: () async {
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
        if (widget.takeDownOnly && !_givenBack && _problem != null)
          OutlinedButton(
            key: const Key('host-force-down'),
            onPressed: _busy ? null : () => _giveBack(anyway: true),
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
