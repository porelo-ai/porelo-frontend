import 'dart:async';

import 'package:flutter/material.dart';

import '../app/machine_binding.dart';
import '../app/project_workspace.dart';
import 'dialog_scroll.dart';
import 'tokens.dart';

/// Opens what a project holds at its forge and at a machine, for after it is set up.
Future<void> showProjectForge(BuildContext context, MachineBinding binding) async {
  await showDialog<void>(
    context: context,
    builder: (_) => ProjectForgeDialog(binding: binding),
  );
  binding.dispose();
}

/// The machines a project trusts, the changes waiting at a machine's gate,
/// and stopping work on it there: **the tools for later**, reached from the project and never in
/// the way of setting it up.
class ProjectForgeDialog extends StatefulWidget {
  /// Constructor taking the binding.
  const ProjectForgeDialog({required this.binding, super.key});

  /// The project's keys and changes at its forge.
  final MachineBinding binding;

  @override
  State<ProjectForgeDialog> createState() => _ProjectForgeDialogState();
}

class _ProjectForgeDialogState extends State<ProjectForgeDialog> {
  List<SigningKey>? _keys;
  SigningKey? _key;
  String? _problem;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  Future<void> _open() async {
    try {
      final workspace = widget.binding.workspace;
      await workspace.open();
      final keys = await workspace.signingKeys();
      if (!mounted) return;
      setState(() {
        _keys = keys;
        if (keys.length == 1 || keys.first.gitSigns) _key = keys.first;
      });
    } on WorkspaceRefused catch (refused) {
      if (mounted) setState(() => _problem = refused.words);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.binding,
    builder: (context, _) {
      final binding = widget.binding;
      final text = Theme.of(context).textTheme;
      final scheme = Theme.of(context).colorScheme;
      final keys = _keys;
      final key = _key;
      final machine = binding.machineName;
      final forge = binding.forge.name;
      return AlertDialog(
        key: const Key('project-forge-dialog'),
        title: Text('${binding.workspace.repository.fullName} at $forge and on $machine'),
        content: SizedBox(
          width: Sizes.dialog,
          child: DialogScroll(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (_problem != null)
                  Text(
                    _problem!,
                    key: const Key('binding-problem'),
                    style: TextStyle(color: scheme.error),
                  ),
                if (binding.problem != null)
                  Text(
                    binding.problem!,
                    key: const Key('binding-problem'),
                    style: TextStyle(color: scheme.error),
                  ),
                if (keys != null && keys.length > 1)
                  DropdownButtonFormField<String>(
                    key: const Key('binding-key'),
                    isExpanded: true,
                    initialValue: key?.fingerprint,
                    decoration: const InputDecoration(labelText: 'The key you sign your commits with'),
                    items: <DropdownMenuItem<String>>[
                      for (final each in keys)
                        DropdownMenuItem<String>(
                          value: each.fingerprint,
                          child: Text(
                            each.comment.isEmpty ? each.fingerprint : each.comment,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (chosen) => setState(() => _key = keys.firstWhere((each) => each.fingerprint == chosen)),
                  ),
                for (final (index, each) in binding.done.indexed)
                  Text(each, key: ValueKey<String>('binding-done $index'), style: text.bodySmall),
                const SizedBox(height: Space.small),
                _section(
                  context,
                  buttonKey: const Key('binding-changes'),
                  button: 'Changes to the project waiting at $machine',
                  explain:
                      'A task on $machine may propose a change to the project, its project.yml say. '
                      'Read the proposed change here and take it, signed with your key.',
                  onPressed: binding.busy ? null : () => unawaited(binding.loadChanges()),
                ),
                if (binding.changes case final changes?) ...<Widget>[
                  if (changes.isEmpty) const Text('Nothing waits.', key: Key('binding-no-changes')),
                  for (final change in changes) ...<Widget>[
                    Row(
                      key: ValueKey<String>('change ${change.name}'),
                      children: <Widget>[
                        Expanded(child: Text('${change.subject} (${change.waiting})')),
                        TextButton(
                          key: ValueKey<String>('review-change ${change.name}'),
                          onPressed: binding.busy ? null : () => unawaited(binding.review(change)),
                          child: const Text('Read it'),
                        ),
                        TextButton(
                          key: ValueKey<String>('merge-change ${change.name}'),
                          // Taken only once it was read, and only with a key to sign it.
                          onPressed: binding.busy || key == null || binding.reviewing != change.name
                              ? null
                              : () => unawaited(binding.merge(change, key)),
                          child: const Text('Take it, signed'),
                        ),
                      ],
                    ),
                    if (binding.reviewing == change.name)
                      SelectableText(
                        binding.reviewDiff,
                        key: ValueKey<String>('change-diff ${change.name}'),
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                  ],
                ],
                _section(
                  context,
                  buttonKey: const Key('binding-remove'),
                  button: 'Stop working on it on $machine',
                  explain:
                      '$machine stops following the project and is taken out of the machines whose messages '
                      'the project trusts. Its vault token stays on the machine.',
                  onPressed: binding.busy || key == null ? null : () => unawaited(binding.remove(key)),
                ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            key: const Key('binding-close'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      );
    },
  );

  Widget _section(
    BuildContext context, {
    required Key buttonKey,
    required String button,
    required String explain,
    required VoidCallback? onPressed,
  }) => Padding(
    padding: const EdgeInsets.only(top: Space.small),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        OutlinedButton(key: buttonKey, onPressed: onPressed, child: Text(button)),
        Text(explain, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}
