import 'dart:async';

import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import '../app/machine_clearing.dart';
import 'dialog_scroll.dart';
import 'tokens.dart';

/// Clears a machine, or a project on it, in one step: what would go is listed first, from the
/// machine's own dry run, and one confirmation does all of it; then what was removed and what was
/// left is said, thing by thing.
Future<void> openClearing(BuildContext context, MachineClearing clearing) async {
  unawaited(clearing.look());
  await showDialog<void>(context: context, builder: (_) => _ClearingDialog(clearing));
  // Closed: a look or a clearing still running says what it found to nobody.
  clearing.dispose();
}

class _ClearingDialog extends StatelessWidget {
  const _ClearingDialog(this.clearing);

  final MachineClearing clearing;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: clearing,
    builder: (context, _) {
      final text = Theme.of(context).textTheme;
      final scheme = Theme.of(context).colorScheme;
      final what = clearing.project ?? 'everything Porelo put there';
      final preview = clearing.preview;
      final cleared = clearing.cleared;
      final over = cleared != null && !cleared.refused;
      return AlertDialog(
        key: const Key('clearing-dialog'),
        title: Text('Clear ${clearing.machineName} of $what'),
        content: SizedBox(
          width: Sizes.dialog,
          child: DialogScroll(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: Space.tight,
              children: <Widget>[
                if (clearing.problem != null)
                  Text(
                    clearing.problem!,
                    key: const Key('clearing-problem'),
                    style: TextStyle(color: scheme.error),
                  ),
                if (preview == null && clearing.problem == null) const Text('Asking the machine what would go…'),
                if (preview != null && cleared == null) ...<Widget>[
                  Text('This goes, on ${clearing.machineName}:', style: text.titleSmall),
                  for (final item in preview.items)
                    Text(
                      item.status == 'FOR_A_PERSON'
                          ? '${item.what}\n${item.why}'
                          : '· ${_kind(item.kind)} ${item.what}',
                      key: ValueKey<String>('clearing-would ${item.what}'),
                    ),
                  for (final key in preview.keys) Text(key.title),
                  const SizedBox(height: Space.small),
                  Text(
                    'Its vault, its keys and what is installed stay: clearing is not uninstalling.',
                    style: text.bodySmall,
                  ),
                ],
                if (cleared != null && cleared.refused)
                  Text(
                    'Nothing was removed: work there is unreviewed or still running. Clearing it all the '
                    'same throws that work away.',
                    key: const Key('clearing-refused'),
                    style: TextStyle(color: scheme.error),
                  ),
                if (over) ...<Widget>[
                  for (final item in cleared.items)
                    Text(
                      item.status == 'FOR_A_PERSON'
                          ? '${item.what}\n${item.why}'
                          : item.status == 'REMOVED'
                          ? 'Removed ${_kind(item.kind)} ${item.what}.'
                          : 'Left ${_kind(item.kind)} ${item.what}${item.why.isEmpty ? '' : ': ${item.why}'}.',
                      key: ValueKey<String>('clearing-done ${item.what}'),
                      style: item.status == 'REMOVED' ? null : TextStyle(color: scheme.error),
                    ),
                  for (final key in cleared.keys) Text(key.title),
                  for (final (index, each) in clearing.done.indexed)
                    Text(
                      each,
                      key: ValueKey<String>('clearing-forge $index'),
                      style: each.startsWith('Left') ? TextStyle(color: scheme.error) : null,
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            key: const Key('clearing-close'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(over ? 'Done' : 'Cancel'),
          ),
          if (!over && preview != null)
            FilledButton(
              key: const Key('clearing-go'),
              style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
              onPressed: clearing.busy ? null : () => unawaited(clearing.clearIt(force: cleared?.refused ?? false)),
              child: Text(cleared?.refused ?? false ? 'Clear it all the same' : 'Clear it'),
            ),
        ],
      );
    },
  );

  /// The machine's kind of thing, as a person reads it: Porelo names them in lower case, `task`,
  /// `mirror`, `image`, `follow`, `conversation`, `transport`, `deploy key`, `signer` (measured on run 278).
  static String _kind(String kind) => switch (kind.toLowerCase().replaceAll('_', ' ')) {
    'task' => 'the work',
    'workspace' => 'the workspace',
    'follow' => 'following',
    'mirror' => 'the mirror',
    'image' => 'the image',
    'gate' => 'the gate',
    'homeserver' => 'the homeserver',
    'conversation' => 'the conversation',
    'transport' => 'the transport’s state:',
    'mailbox' => 'the mailbox',
    final other => other,
  };
}

/// What a person sees of [Cleared] as a whole: kept for tests and the record.
String clearedInWords(Cleared cleared) =>
    '${cleared.items.where((each) => each.status == 'REMOVED').length} removed, '
    '${cleared.items.where((each) => each.status == 'NOT_REMOVED').length} left';
