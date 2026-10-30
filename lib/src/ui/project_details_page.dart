import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import '../app/commands.dart';
import '../app/fleet_model.dart';
import '../app/machines.dart';
import '../app/registry_pages.dart';
import 'command_menu.dart';
import 'expandable_list_row.dart';
import 'filtered_list_section.dart';
import 'projects_page.dart';
import 'registry_persons.dart';
import 'tokens.dart';

/// One project on one machine, without transferring selection on matching names.
class ProjectDetailsPage extends StatelessWidget {
  /// Creates the project's scoped information and lists.
  const ProjectDetailsPage({
    required this.machine,
    required this.project,
    required this.registry,
    required this.commands,
    required this.onBack,
    required this.onMachine,
    this.highlight,
    this.onShown,
    this.details,
    this.admission,
    this.jobs = const [],
    super.key,
  });

  /// The machine this item belongs to.
  final Machine machine;

  /// The project on this specific machine.
  final ProjectOnScreen project;

  /// The verified registry decisions and separate host confirmations.
  final RegistryPages registry;

  /// The exact registry admission opened by the row.
  final RegistryPageItem? admission;

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
    final item = admission;
    final isDefault = project.name == defaultProject;
    return ListView(
      key: ValueKey('project-details ${machine.name}/${project.name}'),
      padding: const EdgeInsets.all(Space.normal),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(onPressed: onBack, icon: const Icon(Icons.arrow_back), label: const Text('Projects')),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                isDefault ? 'Without a project' : project.label,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            CommandMenu(
              key: const Key('project-menu'),
              commands: [...commands],
              tooltip: 'What can be done with ${project.label} on ${machine.name}',
              highlight: highlight,
              onShown: onShown,
            ),
          ],
        ),
        Text('on ${machine.name}${item == null ? '' : ' · ${item.target.registry}'}'),
        if (item != null) Text('${item.role} · ${item.state} · ${registryStateWords(registry, item)}'),
        ?details,
        if (!isDefault) RegistryPersons(registry: registry, item: item),
        FilteredListSection(
          title: 'Machines',
          storageId: 'project-machines ${machine.name}/${project.name}',
          collapsible: true,
          rows: [
            (
              words: machine.name,
              child: ItemListRow(
                title: machine.name,
                subtitle: item == null ? 'Host application state unknown' : registryStateWords(registry, item),
                leading: const Icon(Icons.dns_outlined),
                onOpen: onMachine,
                menu: CommandMenu(
                  tooltip: 'Machine for ${project.label}',
                  commands: [
                    listOpenCommand(label: 'Open the machine', home: Home.machineRow, open: onMachine),
                    if (!isDefault && item != null)
                      ...registryItemCommands(context, registry, item, [RegistryOperation.takeOffHost]),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (jobs.isNotEmpty)
          FilteredListSection(
            title: 'Saved jobs',
            storageId: 'project-jobs ${machine.name}/${project.name}',
            collapsible: true,
            reveal: highlight?.startsWith('template.start/${project.name}/') == true ? highlight : null,
            rows: jobs,
          ),
      ],
    );
  }
}
