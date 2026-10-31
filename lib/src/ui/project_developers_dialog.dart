import 'dart:async';

import 'package:flutter/material.dart';

import '../app/access_developers.dart';
import '../app/commands.dart';
import '../app/fleet_backend.dart';
import '../app/forge_connection.dart';
import '../app/project_access.dart';
import '../app/project_developers.dart';
import 'tokens.dart';
import 'dialog_scroll.dart';

/// Opens the registry picker without accepting person values, keys or secrets by hand.
Future<void> showProjectDevelopers(
  BuildContext context, {
  required String project,
  required FleetBackend backend,
  required ForgeConnection forges,
  ProjectAccess? access,
}) => showDialog<void>(
  context: context,
  builder: (_) => ProjectDevelopersDialog(project: project, access: access),
);

/// The accepted project person list and Core's scoped registry picker.
class ProjectDevelopersDialog extends StatefulWidget {
  /// Uses the same project service as registration and durable recovery.
  const ProjectDevelopersDialog({required this.project, this.access, super.key});

  /// The selected project.
  final String project;

  /// The Core and host adapter, absent until the served contracts are available.
  final ProjectAccess? access;

  @override
  State<ProjectDevelopersDialog> createState() => _ProjectDevelopersDialogState();
}

class _ProjectDevelopersDialogState extends State<ProjectDevelopersDialog> {
  ProjectDevelopers? _developers;
  String? _candidate;
  String? _person;

  @override
  void initState() {
    super.initState();
    if (widget.access case final access?) {
      _developers = ProjectDevelopers(project: widget.project, people: access)..addListener(_changed);
      access.registry.addListener(_changed);
      access.settings.addListener(_changed);
      unawaited(_developers!.load());
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.access?.registry.removeListener(_changed);
    widget.access?.settings.removeListener(_changed);
    _developers?.removeListener(_changed);
    _developers?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final developers = _developers;
    final access = widget.access;
    final cards =
        (developers?.access == null || developers?.problem != null ? null : access?.candidates)
            ?.where((card) => developers?.access?.developers.containsKey(card.login) != true)
            .toList() ??
        [];
    final candidate = cards.where((card) => card.login == _candidate).firstOrNull;
    final people = developers?.access?.developers.values.toList() ?? <AccessDeveloper>[];
    final commands = developers == null
        ? <Command>[]
        : projectPersonCommands(
            developers: developers,
            person: _person,
            add: candidate == null
                ? null
                : () => unawaited(
                    developers.addDeveloper(
                      AccessDeveloper(login: candidate.login, role: 'developer', fingerprint: candidate.fingerprint),
                    ),
                  ),
          );
    return AlertDialog(
      title: Text('Persons in ${widget.project}'),
      content: SizedBox(
        width: Sizes.dialogSmall,
        child: DialogScroll(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: Space.small,
            children: [
              if (access == null) const Text('Verified registry person changes are not available yet.'),
              if (access?.admission case final words?) Text(words),
              if (developers?.problem case final problem?) Text(problem),
              if (access?.unavailable() case final reason?) Text(reason),
              if (developers != null) ...[
                DropdownButtonFormField<String>(
                  key: ValueKey('candidate-${candidate?.login}'),
                  initialValue: candidate?.login,
                  decoration: const InputDecoration(labelText: 'Registry person'),
                  items: [
                    for (final card in cards)
                      DropdownMenuItem(value: card.login, child: Text('${card.name} (${card.login})')),
                  ],
                  onChanged: developers.busy ? null : (value) => setState(() => _candidate = value),
                ),
                RadioGroup<String>(
                  groupValue: _person,
                  onChanged: (value) {
                    if (!developers.busy) setState(() => _person = value);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final person in people)
                        RadioListTile<String>(
                          value: person.login,
                          enabled: !developers.busy,
                          title: Text(person.login),
                          subtitle: Text(
                            '${person.role}${person.locked ? ' · locked in this project' : ''}'
                            '${access?.newKey(person.login) != null ? ' · a new key waits' : ''}',
                          ),
                        ),
                    ],
                  ),
                ),
                for (final command in commands) ...[
                  OutlinedButton(
                    onPressed: command.unavailable == null ? command.run : null,
                    child: Text(command.label),
                  ),
                  if (command.unavailable case final reason?) Text(reason),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    );
  }
}
