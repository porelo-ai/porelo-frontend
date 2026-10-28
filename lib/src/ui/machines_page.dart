import 'dart:async';

import 'package:flutter/material.dart';

import '../app/host_runs.dart';
import '../app/host_session.dart';

import '../app/fleet_model.dart';
import '../app/machines.dart';
import '../app/commands.dart';
import 'command_menu.dart';
import 'expandable_list_row.dart';
import 'host_dialog.dart';
import 'tokens.dart';

/// Lists preparations and machines once for both the page and its navigation count.
({List<HostPreparation> preparations, List<Machine> machines}) machinesPageRows(Machines machines, HostRuns? hostRuns) {
  final preparations = hostRuns?.preparing ?? <HostPreparation>[];
  final preparingNames = preparations.map((run) => run.name).toSet();
  return (
    preparations: preparations,
    machines: machines.all.where((machine) => !preparingNames.contains(machine.name)).toList(),
  );
}

/// Every machine watched, as a list: where work runs, set up rarely (walk 9). One row
/// per machine says how it stands; its details are a page of their own, and its projects and work
/// are under *Projects* and *Work*, never here.
class MachinesPage extends StatelessWidget {
  /// Constructor taking the machines and what choosing does.
  const MachinesPage({
    required this.machines,
    required this.onAdd,
    required this.onDetails,
    required this.onForget,
    this.hostCommands,
    this.hostRuns,
    this.onHostProtocol,
    super.key,
  });

  /// Hosts being prepared before they become machines.
  final HostRuns? hostRuns;

  /// Opens all steps, stderr and any stop terminal of a retained run.
  final void Function(HostPreparation run)? onHostProtocol;

  /// Every machine watched.
  final Machines machines;

  /// Adds a machine: this computer, or one reached over ssh.
  final VoidCallback onAdd;

  /// Opens a machine's details.
  final void Function(Machine machine) onDetails;

  /// Takes a machine off the list, after asking; never the last one.
  final void Function(Machine machine) onForget;

  /// The host's commands, including their reasons when unavailable.
  final List<Command> Function(Machine machine)? hostCommands;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final rows = machinesPageRows(machines, hostRuns);
    return ListView(
      // The key the tree carried: what lists the machines, wherever a step looks for them.
      key: const Key('machine-tree'),
      padding: const EdgeInsets.all(Space.normal),
      children: <Widget>[
        Wrap(
          spacing: Space.normal,
          runSpacing: Space.small,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text('Machines', style: text.headlineSmall),
            FilledButton.icon(
              key: const Key('machines-add'),
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: Sizes.rowIcon),
              label: const Text('Add a machine'),
            ),
          ],
        ),
        const SizedBox(height: Space.tight),
        Text('Where work runs. Its projects are under Projects, and its work under Work.', style: text.bodySmall),
        const SizedBox(height: Space.normal),
        for (final run in rows.preparations)
          _HostPreparationRow(
            key: ValueKey('host-preparing ${run.project}'),
            run: run,
            open: onHostProtocol == null ? null : () => onHostProtocol!(run),
            actions: hostRecoveryCommands(
              run: run,
              goOn: () => unawaited(hostRuns!.resume(run)),
              takeDown: () => unawaited(
                openHostTakeDownDialog(
                  context,
                  project: run.project,
                  machines: machines,
                  settings: machines.settings,
                  hostRuns: hostRuns,
                ),
              ),
            ),
          ),
        for (final machine in rows.machines) _row(context, machine),
      ],
    );
  }

  Widget _row(BuildContext context, Machine machine) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final fleet = machines.of(machine);
    final info = fleet.info;
    final running = fleet.tasks.where((task) => task.running).length;
    final refused = machines.tunnels.of(machine)?.problem;
    final answering = fleet.reachability == Reachability.connected && refused == null;
    final local = Machine.local();
    final thisComputer = !machine.needsATunnel && machine.name == local.name && machine.socketPath == local.socketPath;
    final actions = <Command>[
      ...?hostCommands?.call(machine),
      forgetMachineCommand(
        forget: () => onForget(machine),
        canForget: machines.all.length > 1,
      ).unless(thisComputer ? 'this computer is always listed' : null),
    ];
    final open = listOpenCommand(label: 'Open machine', home: Home.machineRow, open: () => onDetails(machine));
    return ExpandableListRow(
      key: ValueKey<String>('machines-row ${machine.name}'),
      bodyKey: ValueKey<String>('tree-machine ${machine.name}'),
      title: machine.name,
      titleKey: ValueKey<String>('rail-machine ${machine.name}'),
      state: answering ? 'Connected' : 'Not answering',
      primary: open,
      onOpen: open.run,
      leading: Badge(
        key: ValueKey<String>('waiting-count ${machine.name}'),
        isLabelVisible: fleet.clearance.count > 0,
        label: Text('${fleet.clearance.count}'),
        child: Tooltip(
          message:
              '${machine.name}: ${machines.tunnels.of(machine)?.words ?? (answering ? 'Answering' : 'Not answering')}',
          child: Icon(answering ? Icons.dns_outlined : Icons.cloud_off_outlined, size: Sizes.mark),
        ),
      ),
      details: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            <String>[
              machine.where,
              if (info != null) '${info.product} ${info.version}',
              if (answering) running == 1 ? '1 running' : '$running running' else 'not answering',
            ].join('  ·  '),
            style: text.bodySmall,
          ),
          if (refused != null)
            Text(
              refused,
              key: ValueKey<String>('machine-refused ${machine.name}'),
              style: text.bodySmall?.copyWith(color: theme.colorScheme.error),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              PopupMenuButton<String>(
                key: ValueKey<String>('machines-menu ${machine.name}'),
                tooltip: 'What can be done with ${machine.name}',
                onSelected: (id) {
                  final command = actions.firstWhere((command) => command.id == id);
                  if (command.available) command.run();
                },
                itemBuilder: (_) => commandMenuEntries(actions),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HostPreparationRow extends StatefulWidget {
  const _HostPreparationRow({required this.run, required this.actions, this.open, super.key});
  final HostPreparation run;
  final List<Command> actions;
  final VoidCallback? open;

  @override
  State<_HostPreparationRow> createState() => _HostPreparationRowState();
}

class _HostPreparationRowState extends State<_HostPreparationRow> {
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _about(int seconds) => seconds < 60 ? 'about $seconds s' : 'about ${(seconds / 60).ceil()} min';

  @override
  Widget build(BuildContext context) {
    final run = widget.run;
    final session = run.session;
    final running = run.running;
    if (running) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
    final command =
        (run.needsYou
                ? hostPreparationCommand(project: run.project, open: widget.open ?? () {}, home: Home.machineRow)
                : hostProtocolCommand(project: run.project, open: widget.open ?? () {}))
            .unless(widget.open == null ? 'host setup is unavailable here' : null);
    final primary = run.interrupted ? widget.actions.firstWhere((action) => action.id == 'host.goOn') : command;
    return ExpandableListRow(
      leading: Icon(run.needsYou ? Icons.person_outline : Icons.dns_outlined),
      title: run.name,
      state: run.interrupted
          ? 'Interrupted'
          : run.needsYou
          ? 'Needs you'
          : session.state == HostRunState.busy
          ? 'Still running'
          : 'In preparation',
      primary: primary,
      primaryKey: ValueKey('${primary.id} ${run.project}'),
      onOpen: command.available ? command.run : null,
      details: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(run.awaitingVpn ? 'Setting up the VPN' : 'In preparation'),
          if (session.state == HostRunState.busy) Text('Setup of ${run.project} is still running from before.'),
          if (run.interrupted) const Text('Interrupted when the interface closed; the server is still rented'),
          if (session.stepText.isNotEmpty) Text(session.stepText),
          if (running) ...[
            if (session.timeLeftText case final text?) Text(text),
            if (session.stepOverrun case final text?)
              Text(text)
            else if (session.stepSecondsLeft case final seconds?)
              Text('${_about(seconds)} left in this step'),
          ],
          if (run.problem ?? session.fix case final fix?) Text(fix),
          if (command.unavailable case final reason?) Text(reason),
          Wrap(
            spacing: Space.small,
            runSpacing: Space.tight,
            children: [
              for (final action in [command, ...widget.actions].where((action) => action.id != primary.id))
                Tooltip(
                  message: action.unavailable ?? action.label,
                  child: TextButton(
                    key: ValueKey('${action.id} ${run.project}'),
                    onPressed: action.available ? action.run : null,
                    child: Text(action.label),
                  ),
                ),
            ],
          ),
          for (final action in widget.actions)
            if (action.unavailable case final reason?) Text('${action.label}: $reason'),
        ],
      ),
    );
  }
}
