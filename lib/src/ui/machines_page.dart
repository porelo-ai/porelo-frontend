import 'dart:async';

import 'package:flutter/material.dart';

import '../app/host_runs.dart';
import '../app/host_session.dart';

import '../app/fleet_model.dart';
import '../app/machines.dart';
import '../app/session.dart';
import '../app/commands.dart';
import 'command_menu.dart';
import 'expandable_list_row.dart';
import 'host_dialog.dart';
import 'tokens.dart';
import 'filtered_list_section.dart';
import 'projects_page.dart';
import '../app/registry_pages.dart';

/// Lists preparations and machines once for both the page and its navigation count.
({List<HostPreparation> preparations, List<Machine> machines}) machinesPageRows(Machines machines, HostRuns? hostRuns) {
  final preparations = hostRuns?.preparing ?? <HostPreparation>[];
  final preparingNames = preparations.map((run) => run.name).toSet();
  return (
    preparations: preparations,
    machines: machines.all.where((machine) => !preparingNames.contains(machine.name)).toList(),
  );
}

/// Machines and verified admissions, with navigation and operations on every row.
class MachinesPage extends StatelessWidget {
  /// Creates the Machines list and its setup entry points.
  const MachinesPage({
    required this.machines,
    required this.onAdd,
    required this.onDetails,
    required this.onForget,
    this.hostCommands,
    this.hostRuns,
    this.onHostProtocol,
    this.openTerminal,
    this.registry,
    this.onAdmission,
    this.prepareServer,
    super.key,
  });

  /// The watched machines and their daemon state.
  final Machines machines;

  /// Opens the machine setup entry point.
  final VoidCallback onAdd;

  /// Opens the selected machine page.
  final void Function(Machine machine) onDetails;

  /// Previews forgetting this specific machine.
  final void Function(Machine machine) onForget;

  /// Creates the commands for this host.
  final List<Command> Function(Machine machine)? hostCommands;

  /// The retained server preparation runs.
  final HostRuns? hostRuns;

  /// Opens a retained setup protocol.
  final void Function(HostPreparation run)? onHostProtocol;

  /// The injected terminal boundary for machine operations.
  final OpenTerminal? openTerminal;

  /// The verified registry decisions and separate host confirmations.
  final RegistryPages? registry;

  /// Opens the exact host admission, including its registry identity.
  final void Function(RegistryPageItem item)? onAdmission;

  /// The server preparation command and its refusal.
  final Command? prepareServer;

  @override
  Widget build(BuildContext context) {
    final rows = machinesPageRows(machines, hostRuns);
    return ListView(
      key: const Key('machine-tree'),
      padding: const EdgeInsets.all(Space.normal),
      children: [
        if (registry?.problem case final problem?) Text(problem),
        FilteredListSection(
          title: 'Machines',
          storageId: 'machines',
          actions: [
            FilledButton.icon(
              key: const Key('machines-add'),
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add a machine'),
            ),
            if (prepareServer case final command?)
              if (command.visible)
                Tooltip(
                  message: command.unavailable ?? command.label,
                  child: OutlinedButton(
                    key: const Key('host.prepare'),
                    onPressed: command.available ? command.run : null,
                    child: Text(command.label),
                  ),
                ),
          ],
          rows: [
            for (final run in rows.preparations)
              (
                words: '${run.name} ${_hostState(run)}',
                child: _HostPreparationRow(
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
                        openTerminal: openTerminal,
                      ),
                    ),
                  ),
                ),
              ),
            for (final row in scopedMachineRows(machines, registry))
              if (!rows.preparations.any((run) => run.name == row.machine.name))
                (
                  words:
                      '${row.machine.name} ${row.machine.where} ${row.admission?.role ?? ''} ${row.admission?.target.registry ?? ''}',
                  child: _row(context, row.machine, admission: row.admission),
                ),
          ],
        ),
      ],
    );
  }

  Widget _row(BuildContext context, Machine machine, {RegistryPageItem? admission}) {
    final watched = machines.all.contains(machine);
    final fleet = watched ? machines.of(machine) : null;
    final tunnel = watched ? machines.tunnels.of(machine) : null;
    admission ??= registry?.host(machine);
    final item = admission;
    void open() {
      if (item != null && onAdmission != null) {
        onAdmission!(item);
      } else {
        onDetails(machine);
      }
    }

    final identity = item == null ? machine.name : '${item.target.registry}/${item.target.host}';
    final local = Machine.local();
    final thisComputer = machine.name == local.name && machine.socketPath == local.socketPath;
    final actions = <Command>[
      listOpenCommand(label: 'Open the machine', home: Home.machineRow, open: open),
      ...?hostCommands?.call(machine),
      if (watched &&
          hostRuns != null &&
          machine.kind == 'host' &&
          machines.settings.hostUp(machine.hostProject) != null)
        runHostSetupAgainCommand(project: machine.hostProject, hostRuns: hostRuns!),
      if (watched)
        forgetMachineCommand(
          forget: () => onForget(machine),
          canForget: machines.all.length > 1,
          machine: machine,
          hostRuns: hostRuns,
        ).unless(thisComputer ? 'this computer is always listed' : null),
    ];
    return ItemListRow(
      key: ValueKey('machines-row $identity'),
      bodyKey: ValueKey('tree-machine $identity'),
      titleKey: ValueKey('rail-machine ${machine.name}'),
      title: thisComputer ? 'This computer' : machine.name,
      subtitle: [
        machine.where,
        if (admission != null) ...[admission.role, admission.state, registryStateWords(registry!, admission)],
        if (tunnel != null)
          tunnel.words
        else if (fleet?.reachability == Reachability.connected)
          'Connected'
        else
          'Not connected; state unknown',
        ?tunnel?.problem,
      ].join(' · '),
      leading: const Icon(Icons.dns_outlined),
      onOpen: open,
      menu: CommandMenu(
        key: ValueKey('machines-menu $identity'),
        commands: actions,
        tooltip: 'What can be done with ${machine.name}',
      ),
    );
  }
}

String _hostState(HostPreparation run) => run.interrupted
    ? 'Interrupted'
    : run.needsYou
    ? 'Needs you'
    : run.ready
    ? 'Setting up again'
    : run.session.state == HostRunState.busy
    ? 'Still running'
    : 'In preparation';

Command _hostProtocol(HostPreparation run, VoidCallback? open) =>
    (run.needsYou && !run.ready
            ? hostPreparationCommand(project: run.project, open: open ?? () {}, home: Home.machineRow)
            : hostProtocolCommand(project: run.project, open: open ?? () {}))
        .unless(open == null ? 'host setup is unavailable here' : null);

class _HostPreparationRow extends StatelessWidget {
  const _HostPreparationRow({required this.run, required this.actions, this.open, super.key});
  final HostPreparation run;
  final List<Command> actions;
  final VoidCallback? open;

  @override
  Widget build(BuildContext context) {
    final command = _hostProtocol(run, open);
    return ItemListRow(
      leading: Icon(run.needsYou ? Icons.person_outline : Icons.dns_outlined),
      title: run.name,
      subtitle: '${_hostState(run)} · ${run.problem ?? run.session.fix ?? run.session.stepText}',
      onOpen: command.available ? command.run : null,
      menu: CommandMenu(commands: [command, ...actions], tooltip: 'Setup of ${run.name}'),
    );
  }
}
