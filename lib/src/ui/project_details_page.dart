import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import '../app/commands.dart';
import '../app/fleet_model.dart';
import '../app/machines.dart';
import 'command_menu.dart';
import 'expandable_list_row.dart';
import 'filtered_list_section.dart';
import 'tokens.dart';
import 'page_explanation.dart';

/// One project on one machine, without transferring selection on matching names.
class ProjectDetailsPage extends StatelessWidget {
  /// Creates the project's scoped information and lists.
  const ProjectDetailsPage({
    required this.machine,
    required this.project,
    required this.commands,
    required this.onBack,
    required this.onMachine,
    this.highlight,
    this.onShown,
    this.details,
    this.jobs = const [],
    super.key,
  });

  /// The machine this item belongs to.
  final Machine machine;

  /// The project on this specific machine.
  final ProjectOnScreen project;

  /// The commands scoped to this item.
  final List<Command> commands;

  /// Returns to the containing list.
  final VoidCallback onBack;

  /// Opens the machine belonging to this item.
  final VoidCallback onMachine;

  /// The command the finder is revealing.
  final String? highlight;

  /// Reports that the finder destination is visible.
  final VoidCallback? onShown;

  /// The additional information belonging to this item.
  final Widget? details;

  /// The saved jobs available on this project.
  final List<FilteredRow> jobs;

  @override
  Widget build(BuildContext context) {
    final isDefault = project.name == defaultProject;
    return ListView(
      key: ValueKey('project-details ${machine.name}/${project.name}'),
      padding: const EdgeInsets.all(Space.normal),
      children: [
        PageHead(
          title: isDefault ? 'Default' : project.label,
          path: [(label: 'My projects', go: onBack)],
          subtitle: 'on ${machine.name}',
          action: CommandMenu(
            key: const Key('project-menu'),
            commands: commands,
            tooltip: 'What can be done with ${project.label} on ${machine.name}',
            highlight: highlight,
            onShown: onShown,
          ),
        ),
        ?details,
        FilteredListSection(
          title: 'Machines',
          leaf: true,
          subtitle: '1 machine',
          storageId: 'project-machines ${machine.name}/${project.name}',
          collapsible: true,
          rows: [
            (
              words: machine.name,
              child: ItemListRow(
                title: machine.name,
                state: 'not read',
                subtitle: machine.where,
                leading: const Icon(Icons.dns_outlined),
                onOpen: onMachine,
                menu: CommandMenu(
                  tooltip: 'Machine for ${project.label}',
                  commands: [listOpenCommand(label: 'Open the machine', home: Home.machineRow, open: onMachine)],
                ),
              ),
            ),
          ],
        ),
        if (jobs.isNotEmpty)
          FilteredListSection(
            title: 'Saved jobs',
            leaf: true,
            subtitle: '${jobs.length} saved jobs',
            storageId: 'project-jobs ${machine.name}/${project.name}',
            collapsible: true,
            reveal: highlight?.startsWith('template.start/${project.name}/') == true ? highlight : null,
            rows: jobs,
          ),
      ],
    );
  }
}
