import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:porelo_host/porelo_host.dart' show PreparedHost, HostPreparationSettings;

import '../app/fleet_backend.dart';
import '../app/host_runs.dart';
import '../app/host_access.dart';
import '../app/host_session.dart';
import '../app/machines.dart';
import '../app/session.dart';
import '../app/settings.dart';
import '../app/signed_host_actions.dart';
import 'project_bring_dialog.dart';
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

/// Opens registration using verified state from Core.
Future<void> openHostDialog(
  BuildContext context, {
  required String project,
  required Machines machines,
  required Settings settings,
  required FleetBackend backend,
  OpenTerminal? openTerminal,
  SignedHostActions? actions,
}) => showDialog<void>(
  context: context,
  builder: (_) =>
      ProjectBringDialog(project: project, machines: machines, settings: settings, backend: backend, actions: actions),
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

  /// Registry lifecycle operations for standalone give-back.
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
  bool _busy = false;
  bool _givenBack = false;
  String? _problem;
  HostPreparationSettings _choices = const HostPreparationSettings();
  Settings get _settings => widget.settings ?? widget.machines.settings;
  HostUpRecord? get _record => _settings.hostUp(widget.project);

  @override
  void initState() {
    super.initState();
    _choices = _record?.preparationSettings ?? widget.existingRun?.record.preparationSettings ?? _choices;
    _givenBack = _settings.hostReturned(widget.project);
    _problem = pendingHostRegistryGiveBack(
      host: widget.project,
      settings: _settings,
      access: widget.hostAccess ?? widget.hostRuns?.hostAccess,
    );
  }

  Future<void> _giveBack({bool anyway = false}) async {
    if (_busy || _givenBack || _record == null) return;
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
    try {
      await session.down(giveBackAnyway: record.legacy || anyway);
      if (!hostGivenBack(session)) {
        throw StateError('Give-back was not confirmed.');
      }
      final owner = widget.hostRuns;
      if (owner != null) {
        _problem = await owner.confirmDown(widget.project, session);
      } else {
        _problem = await confirmHostRegistryGiveBack(
          host: widget.project,
          session: session,
          settings: _settings,
          access: widget.hostAccess,
        );
        await _settings.forgetHostUp(widget.project);
      }
      for (final machine
          in widget.machines.all.where((m) => m.kind == 'host' && m.hostProject == widget.project).toList()) {
        await widget.machines.forget(machine);
      }
      _givenBack = true;
    } catch (_) {
      _problem = 'Give-back was not confirmed. The rental and recovery data were kept.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _down?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final record = _record ?? widget.existingRun?.record;
    final legacy = record?.legacy == true;
    final access = widget.hostAccess ?? widget.hostRuns?.hostAccess;
    return AlertDialog(
      title: Text(widget.takeDownOnly ? 'Give the server back' : widget.existingRun?.name ?? 'Prepare a server'),
      content: SizedBox(
        width: Sizes.dialog,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (legacy) const Text(HostUpRecord.legacyExplanation),
              if (widget.takeDownOnly && !_givenBack)
                Text(
                  legacy
                      ? 'Giving this rental back deletes what it holds without running its old backup or teardown. Confirm this only when its contents are no longer needed.'
                      : 'Give this server back only after its data is safe. The provider must confirm its removal.',
                ),
              if (!widget.takeDownOnly && widget.existingRun == null)
                const Text('Verified SSH-only server preparation is not available yet.'),
              if (!widget.takeDownOnly && widget.existingRun == null && record?.preparedHost == null && !legacy) ...[
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
                if (access != null && access.unavailable() == null) ...[
                  const Text(
                    'Before setup, run this in a separate terminal on the server. It replaces root’s authorized keys with your host admin card key.',
                  ),
                  SelectableText(access.bootstrapCommand()),
                ],
              ],
              if (_problem != null) Text(_problem!),
              if (_problem != null && !_givenBack && !legacy && widget.takeDownOnly)
                const Text(
                  'Giving back without a backup deletes everything still on the server. Confirm only when its contents are no longer needed.',
                ),
              if (!widget.takeDownOnly)
                if (record?.preparedHost case final host?)
                  PreparedHostPanel(
                    host: host,
                    published:
                        jsonEncode(_settings.hostRegistryState(widget.project).publishedCard?.stored) ==
                        jsonEncode(host.stored),
                  ),
              if (_givenBack) const Text('The provider confirmed give-back.'),
              if (widget.existingRun case final run?)
                ListenableBuilder(listenable: run.session, builder: (_, _) => SelectableText(run.session.protocolText)),
              if (_down case final session?)
                ListenableBuilder(listenable: session, builder: (_, _) => SelectableText(session.protocolText)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Close')),
        if (widget.takeDownOnly && !_givenBack)
          FilledButton(
            key: const Key('host-confirm-down'),
            onPressed: _busy || record == null || widget.hostRuns?.of(widget.project)?.running == true
                ? null
                : () => _giveBack(),
            child: const Text('Give the server back'),
          ),
        if (widget.takeDownOnly && !_givenBack && !legacy && _problem != null)
          OutlinedButton(
            key: const Key('host-force-down'),
            onPressed: _busy ? null : () => _giveBack(anyway: true),
            child: const Text('Give back without a backup'),
          ),
        if (!widget.takeDownOnly && legacy)
          FilledButton(
            onPressed: widget.hostRuns?.againUnavailable(widget.project) == null && widget.hostRuns != null
                ? () => unawaited(widget.hostRuns!.again(widget.project))
                : null,
            child: const Text('Set it up again'),
          ),
      ],
    );
  }
}

/// The checked completion's registry publication state.
class PreparedHostPanel extends StatelessWidget {
  /// Shows whether the signed completion has reached the registry.
  const PreparedHostPanel({required this.host, this.published = false, super.key});

  /// The checked public completion retained for publication retry.
  final PreparedHost host;

  /// Whether the signed card has reached the registry.
  final bool published;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: Space.small,
    children: [
      Text('Host registry', style: Theme.of(context).textTheme.titleMedium),
      Text(
        published ? 'The signed host card is published in the registry.' : 'The host is ready. Publish its signed card in the registry; retrying publication does not prepare another server.',
      ),
    ],
  );
}
