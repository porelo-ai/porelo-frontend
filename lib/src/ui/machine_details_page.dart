import 'package:flutter/material.dart';

import '../app/commands.dart';
import '../app/machines.dart';
import '../app/fleet_model.dart';
import '../app/registry_pages.dart';
import 'command_menu.dart';
import 'filtered_list_section.dart';
import 'projects_page.dart';
import 'registry_persons.dart';
import 'tokens.dart';

/// One machine's information, Projects, and verified Persons.
class MachineDetailsPage extends StatelessWidget {
  /// Creates a machine page with its own scoped commands.
  const MachineDetailsPage({
    required this.machine,
    required this.machines,
    required this.registry,
    required this.commands,
    required this.onBack,
    required this.onProject,
    required this.projectCommands,
    this.tools,
    this.admission,
    this.onAdmission,
    this.menuForAdmission,
    this.highlight,
    this.onShown,
    super.key,
  });

  /// The machine this item belongs to.
  final Machine machine;

  /// The watched machines and their daemon state.
  final Machines machines;

  /// The verified registry decisions and separate host confirmations.
  final RegistryPages registry;

  /// The exact host admission opened by the row.
  final RegistryPageItem? admission;

  /// Opens a project with its complete registry identity.
  final void Function(RegistryPageItem item)? onAdmission;

  /// Creates project commands for the exact admission being rendered.
  final List<Command> Function(Machine machine, ProjectOnScreen project, RegistryPageItem? admission)? menuForAdmission;

  /// The commands scoped to this item.
  final List<Command> commands;

  /// Returns to the containing list.
  final VoidCallback onBack;

  /// Opens a project on its exact machine.
  final void Function(String project) onProject;

  /// Creates commands for each project on this machine.
  final List<Command> Function(ProjectOnScreen project) projectCommands;

  /// The machine tools retained beside its information.
  final Widget? tools;

  /// The command the finder is revealing.
  final String? highlight;

  /// Reports that the finder destination is visible.
  final VoidCallback? onShown;

  @override
  Widget build(BuildContext context) {
    final item = admission;
    return ListView(
      key: ValueKey('machine-details ${machine.name}'),
      padding: const EdgeInsets.all(Space.normal),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(onPressed: onBack, icon: const Icon(Icons.arrow_back), label: const Text('Machines')),
        ),
        Row(
          children: [
            Expanded(child: Text(machine.name, style: Theme.of(context).textTheme.headlineSmall)),
            CommandMenu(
              key: const Key('machine-menu'),
              commands: [
                ...commands,
                if (item != null) ...registryItemCommands(context, registry, item, [RegistryOperation.bringState]),
              ],
              tooltip: 'What ${machine.name} can be told to do',
              highlight: highlight,
              onShown: onShown,
            ),
          ],
        ),
        Text(machine.where),
        if (item != null) Text('${item.role} · ${item.state} · ${registryStateWords(registry, item)}'),
        if (machines.all.contains(machine))
          Text(
            machines.tunnels.of(machine)?.words ??
                (machines.of(machine).reachability == Reachability.connected
                    ? 'Connected'
                    : 'Not connected; last known state'),
          ),
        ?tools,
        FilteredListSection(
          key: ValueKey('machine-projects ${machine.name}'),
          title: 'Projects',
          storageId: 'machine-projects ${machine.name}',
          collapsible: true,
          actions: [
            if (item != null)
              for (final command in registryItemCommands(context, registry, item, [RegistryOperation.admit]))
                Tooltip(
                  message: command.unavailable ?? command.label,
                  child: TextButton(onPressed: command.available ? command.run : null, child: Text(command.label)),
                ),
          ],
          rows: [
            for (final row in scopedProjectRows(machines, machine, registry: registry))
              if (item == null || row.admission == null || row.admission!.target.registry == item.target.registry)
                (
                  words: '${row.project.name} ${row.admission?.target.registry ?? ''}',
                  child: projectListRow(
                    machine: machine,
                    project: row.project,
                    machines: machines,
                    registry: registry,
                    admission: row.admission,
                    onOpen: () {
                      if (row.admission != null && onAdmission != null) {
                        onAdmission!(row.admission!);
                      } else {
                        onProject(row.project.name);
                      }
                    },
                    commands:
                        menuForAdmission?.call(machine, row.project, row.admission) ?? projectCommands(row.project),
                  ),
                ),
          ],
        ),
        RegistryPersons(registry: registry, item: item),
      ],
    );
  }
}
