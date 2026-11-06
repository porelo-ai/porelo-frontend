import 'package:flutter/material.dart';

import '../app/commands.dart';
import '../app/machines.dart';
import '../app/fleet_model.dart';
import 'command_menu.dart';
import 'filtered_list_section.dart';
import 'machine_switcher.dart';
import 'projects_page.dart';
import 'tokens.dart';

/// One machine's information and Projects.
class MachineDetailsPage extends StatelessWidget {
  /// Creates a machine page with its own scoped commands.
  const MachineDetailsPage({
    required this.machine,
    required this.machines,
    required this.commands,
    required this.onBack,
    required this.onProject,
    required this.projectCommands,
    this.tools,
    this.highlight,
    this.onShown,
    this.embedded = false,
    super.key,
  });

  /// The machine this item belongs to.
  final Machine machine;

  /// The watched machines and their daemon state.
  final Machines machines;

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

  /// Whether it stands inside a machine's one page, which has the way back and the name.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final menu = CommandMenu(
      key: const Key('machine-menu'),
      commands: commands,
      tooltip: 'What ${machine.name} can be told to do',
      highlight: highlight,
      onShown: onShown,
    );
    final children = <Widget>[
      if (embedded)
        Align(alignment: Alignment.centerRight, child: menu)
      else ...[
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
            label: const Text('My machines'),
          ),
        ),
        Row(
          children: [
            Expanded(child: Text(machine.name, style: Theme.of(context).textTheme.headlineSmall)),
            menu,
          ],
        ),
      ],
      // The way in decides what silence and closing the window do; a node reached twice is said once.
      Text('${machine.where}${machineKind(machines, machine)}', key: const Key('machine-kind')),
      if (machines.all.contains(machine))
        Text(
          machines.tunnels.of(machine)?.words ??
              // An organization's machine has a second connection, the one work starts through, said on its page:
              // this one is the window's to the machine's Porelo, and says so.
              (machines.of(machine).reachability == Reachability.connected
                  ? (machine.hostCard == null ? 'Connected' : 'This window reaches its Porelo')
                  : (machine.hostCard == null
                        ? 'Not connected; last known state'
                        : 'This window does not reach its Porelo now; last known state')),
        ),
      ?tools,
      FilteredListSection(
        key: ValueKey('machine-projects ${machine.name}'),
        title: 'Projects',
        storageId: 'machine-projects ${machine.name}',
        collapsible: true,
        rows: [
          for (final project in projectsOnMachine(machines, machine))
            (
              words: project.name,
              child: projectListRow(
                machine: machine,
                project: project,
                machines: machines,
                onOpen: () => onProject(project.name),
                commands: projectCommands(project),
              ),
            ),
        ],
      ),
    ];
    return embedded
        ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)
        : ListView(
            key: ValueKey('machine-details ${machine.name}'),
            padding: const EdgeInsets.all(Space.normal),
            children: children,
          );
  }
}
